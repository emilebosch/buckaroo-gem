require './test/test_helper.rb'
require './test/support/sshproxy_helpers'
require 'sinatra'
require 'capybara/dsl'
require 'capybara/poltergeist'
require 'logger'

FileUtils.mkdir_p 'tmp'
$LOGGER = Logger.new('tmp/logfile.log')
$LOGGER.level = Logger::DEBUG

class MyApp < Sinatra::Base

  post '/push' do
    puts "RECEIVED PUSH"
    puts params
    "PUSH IT"
  end

  post '/' do
    puts 'RECEIVED CALLBACK'
    $received = params
    $LOGGER.debug "Callback data received: #{params}"
    "GOT IT"
  end
end

describe "integration test" do
  include Capybara::DSL
  include Helpers::SSHProxy

  def setup
    Capybara.register_driver :poltergeist_debug do |app|
      Capybara::Poltergeist::Driver.new(app, :debug => true)
    end

    Capybara.default_driver = Capybara.javascript_driver = :poltergeist
    Capybara.default_wait_time = 5
    Capybara.app = MyApp.new

    host = Capybara.current_session.server.host
    port = Capybara.current_session.server.port

    Buckaroo.callback = "http://#{host}:#{port}/"
  end

  def teardown
    Capybara.reset_session!
  end

  it "should be able to receive a push" do

    begin
      setup_ssh_proxy ssh_host: ENV['SSH_HOST'], ssh_user: ENV['SSH_USER'], remote_port: 8080, exposed_as_port: 80

      Buckaroo.push     = "#{ssh_proxy_url}/push"
      Buckaroo.callback = ssh_proxy_url

      response = Buckaroo.request_payment!({
        invoice_number: '23',
        description: 'Bank overboeking',
        amount: 200
      })

      assert response.pending_input?, "response should be valid"
      assert response.redirect_url, "response should have a redirect url"

      visit response.redirect_url

      overmaking = find(:css, "[for='method_transfer']")
      overmaking.click

      assert has_content? 'Uw betaling'

      fill_in 'Voornaam',     with: 'Hello'
      fill_in 'Achternaam',   with: 'Awesome'
      fill_in 'E-Mail adres', with: 'infado@pushasd.com'

      click_button 'Verder'

      assert has_content?('Uw betaling is geaccepteerd.'), 'Not on uw betaling is geaccepteerd'
      click_button 'Verder'

      assert page.has_text?("GOT IT"), "Page should contain text GOT IT, are we redirected?"

    ensure
      teardown_ssh_proxy
    end
  end

  def assert(*args)
    passed = super(*args)
    ensure
    puts page.html unless passed
  end

  it "should be able to request a transaction status" do

    response = Buckaroo.request_payment!({
      invoice_number: '12',
      description: 'Bank overboeking',
      amount: 200
    })

    message = Buckaroo.status!(response.transaction)
  end

  it "should process when someone cancels a payment in buckaroo" do
  end

  it "should process an overboeking with pending" do

    response = Buckaroo.request_payment!({
      invoice_number: '23',
      description: 'Bank overboeking',
      amount: 200
    })

    assert response.pending_input?, "response should be valid"
    assert response.redirect_url, "response should have a redirect url"

    visit response.redirect_url

    overmaking = find(:css, "[for='method_transfer']")
    overmaking.click

    assert has_content? 'Uw betaling'

    fill_in 'Voornaam',     with: 'Captain'
    fill_in 'Achternaam',   with: 'Awesome'
    fill_in 'E-Mail adres', with: 'info@captainawesomeomg.com'

    click_button 'Verder'
    assert has_content? 'Uw betaling is geaccepteerd.'
    click_button 'Verder'

    assert page.has_text?("GOT IT"), "Page should contain text GOT IT, are we redirected?"

    callback = Buckaroo::WebCallback.new($received)
    assert callback.valid?, "Callback should be valid"
  end

  it "should process an ABN amro bank /w no pending" do

    response = Buckaroo.request_payment!({
      invoice_number: '23',
      description: 'Ideal',
      amount: 200
    })

    assert response.pending_input?, "response should be valid"
    assert response.redirect_url, "response should have a redirect url"

    visit response.redirect_url

    ideal = find(:css, "[for='method_ideal']")

    assert ideal, "ideal link cannot be found on page"
    assert ideal.text == 'iDEAL', "first element should have been ideal"

    ideal.click

    select('ABNAMRO Bank', :from => 'Uw bank')
    click_button "Verder"

    select("190 - Succes", :from => 'sc')
    click_button "Submit status"

    assert page.has_text?("GOT IT"), "Page should contain text GOT IT, are we redirected?"

    callback = Buckaroo::WebCallback.new($received)
    assert callback.valid?, "not valid?"
  end

end