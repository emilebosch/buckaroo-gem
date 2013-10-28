require './test/test_helper.rb'
require 'sinatra'
require 'capybara/dsl'
require 'capybara/poltergeist'
require 'logger'

FileUtils.mkdir_p 'tmp'
$LOGGER = Logger.new('tmp/logfile.log')
$LOGGER.level = Logger::DEBUG

class MyApp < Sinatra::Base
  post '/' do
    $received = params
    $LOGGER.debug "Callback data received: #{params}"
    "GOT IT"
  end
end

describe "Integration test" do
  include Capybara::DSL

  def setup
    Capybara.app = app = MyApp.new
    Capybara.default_driver = :poltergeist
    Buckaroo.callback = "http://localhost:#{Capybara.current_session.server.port}/"
  end

  def teardown
    Capybara.reset_session!
  end

  it "it should process an overboeking with pending" do

    response = Buckaroo::Charge.create!({
      description: 'Bank overboeking',
      amount: 200,
      currency: 'EUR',
    })

    assert response.valid?, "response should be valid"
    assert response.redirect_url, "response should have a redirect url"

    p response.redirect_url

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

  it "it should process an ABN amro bank /w no pending" do

    response = Buckaroo::Charge.create!({
      description: 'Ideal',
      amount: 200,
      currency: 'EUR',
    })

    assert response.valid?, "response should be valid"
    assert response.redirect_url, "response should have a redirect url"

    p response.redirect_url
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
    assert callback.valid?
  end
end

describe "Buckaroo::WebCallback" do

  it "should properly validate a web callback" do
    p = {"BRQ_AMOUNT"=>"100.00", "BRQ_CURRENCY"=>"EUR", "BRQ_CUSTOMER_NAME"=>"J. de Tèster", "BRQ_INVOICENUMBER"=>"sasad", "BRQ_PAYMENT"=>"B13DF6097C4945A39CB2BA118A437B42", "BRQ_PAYMENT_METHOD"=>"ideal", "BRQ_SERVICE_IDEAL_CONSUMERBIC"=>"RABONL2U", "BRQ_SERVICE_IDEAL_CONSUMERIBAN"=>"NL44RABO0123456789", "BRQ_SERVICE_IDEAL_CONSUMERISSUER"=>"ABNAMRO Bank ", "BRQ_SERVICE_IDEAL_CONSUMERNAME"=>"J. de Tèster", "BRQ_STATUSCODE"=>"190", "BRQ_STATUSCODE_DETAIL"=>"S001", "BRQ_STATUSMESSAGE"=>"Payment successfully processed", "BRQ_TEST"=>"true", "BRQ_TIMESTAMP"=>"2013-10-28 11:31:01", "BRQ_TRANSACTIONS"=>"A4EDB605DC594F2D9CFBDBABABFC9FE4", "BRQ_WEBSITEKEY"=>"2EwHAHd454", "BRQ_SIGNATURE"=>"aa1860a3cdadad2b3abf9514aa47fdc28395d95b"}
    callback = Buckaroo::WebCallback.new(p)
    assert callback.valid?, "should be valid"
  end

end

describe "Buckaroo::Hasher" do

  it "should validate a valid hash" do
    p = {"BRQ_AMOUNT"=>"100.00", "BRQ_CURRENCY"=>"EUR", "BRQ_CUSTOMER_NAME"=>"J. de Tèster", "BRQ_INVOICENUMBER"=>"sasad", "BRQ_PAYMENT"=>"B13DF6097C4945A39CB2BA118A437B42", "BRQ_PAYMENT_METHOD"=>"ideal", "BRQ_SERVICE_IDEAL_CONSUMERBIC"=>"RABONL2U", "BRQ_SERVICE_IDEAL_CONSUMERIBAN"=>"NL44RABO0123456789", "BRQ_SERVICE_IDEAL_CONSUMERISSUER"=>"ABNAMRO Bank ", "BRQ_SERVICE_IDEAL_CONSUMERNAME"=>"J. de Tèster", "BRQ_STATUSCODE"=>"190", "BRQ_STATUSCODE_DETAIL"=>"S001", "BRQ_STATUSMESSAGE"=>"Payment successfully processed", "BRQ_TEST"=>"true", "BRQ_TIMESTAMP"=>"2013-10-28 11:31:01", "BRQ_TRANSACTIONS"=>"A4EDB605DC594F2D9CFBDBABABFC9FE4", "BRQ_WEBSITEKEY"=>"2EwHAHd454", "BRQ_SIGNATURE"=>"aa1860a3cdadad2b3abf9514aa47fdc28395d95b"}
    assert Buckaroo::Hasher.valid?(p, Buckaroo.secret), "Should be valid"
  end

  it "should not validate an invalid hash" do
    p = {"BRQ_AMOUNT"=>"100.10", "BRQ_CURRENCY"=>"EUR", "BRQ_CUSTOMER_NAME"=>"J. de Tèster", "BRQ_INVOICENUMBER"=>"sasad", "BRQ_PAYMENT"=>"B13DF6097C4945A39CB2BA118A437B42", "BRQ_PAYMENT_METHOD"=>"ideal", "BRQ_SERVICE_IDEAL_CONSUMERBIC"=>"RABONL2U", "BRQ_SERVICE_IDEAL_CONSUMERIBAN"=>"NL44RABO0123456789", "BRQ_SERVICE_IDEAL_CONSUMERISSUER"=>"ABNAMRO Bank ", "BRQ_SERVICE_IDEAL_CONSUMERNAME"=>"J. de Tèster", "BRQ_STATUSCODE"=>"190", "BRQ_STATUSCODE_DETAIL"=>"S001", "BRQ_STATUSMESSAGE"=>"Payment successfully processed", "BRQ_TEST"=>"true", "BRQ_TIMESTAMP"=>"2013-10-28 11:31:01", "BRQ_TRANSACTIONS"=>"A4EDB605DC594F2D9CFBDBABABFC9FE4", "BRQ_WEBSITEKEY"=>"2EwHAHd454", "BRQ_SIGNATURE"=>"aa1860a3cdadad2b3abf9514aa47fdc28395d95b"}
    assert !Buckaroo::Hasher.valid?(p, Buckaroo.secret), "Should not be valid"
  end

  it "should raise on invalid parameters" do
    assert_raises(ArgumentError) do
      Buckaroo::Hasher.calculate(nil, 'secret')
    end

    assert_raises(ArgumentError) do
      Buckaroo::Hasher.calculate({hash: 'hello'} ,nil)
    end
  end

  it "should properly sort the hash before signing" do
    a = Buckaroo::Hasher.calculate({a:'HELLO',  b:'ok',     c:'ok'},'secret')
    b = Buckaroo::Hasher.calculate({b:'ok',     a:'HELLO' , c:'ok'},'secret')
    assert a == b, "Should sign properly"
  end

  it "should hash a request" do
    hash = {name:'hello'}
    signature = Buckaroo::Hasher.calculate(hash, 'im a secret')
    assert 'a8058903eea2b869ecae917442e7e9a99694421b' ==  signature, "Should sign properly"
  end

end