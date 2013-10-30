module Helpers

  module SSHProxy
    attr_accessor :ssh_pid, :ssh_proxy_url

    def setup_ssh_proxy(opts)
      host = Capybara.current_session.server.host
      port = Capybara.current_session.server.port

      connected    = false
      seconds_left = 20

      ssh_user     = opts[:ssh_user] || raise('No :ssh_user given')
      ssh_server   = opts[:ssh_host] || raise('No :ssh_host given')

      remote_port  = opts[:remote_port]     || port
      exposed_port = opts[:exposed_as_port] || port

      self.ssh_pid = Process.spawn('ssh','-R', "*:#{remote_port}:#{host}:#{port}", "#{ssh_user}@#{ssh_server}", '-N')

      puts "Waiting max #{seconds_left} seconds for server #{ssh_server}:#{exposed_port} to accept connections.."
      until connected || ((seconds_left -= 1) == 0) do
        sleep 1
        begin
          TCPSocket.new ssh_server, exposed_port
          connected = true
          puts "Server #{ssh_server} responded to connections of server.."
        rescue
        end
      end
      throw 'Server didnt responded within time' if seconds_left == 0
      self.ssh_proxy_url = "http://#{ssh_server}#{exposed_port != 80 ? exposed_port : ''}"
    end

    def teardown_ssh_proxy
      return unless self.ssh_pid
      Process.kill 'TERM', self.ssh_pid
      Process.waitpid self.ssh_pid
    end

  end
end