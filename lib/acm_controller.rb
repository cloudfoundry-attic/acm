require "acm/config"
require "acm/api_controller"

require "sequel"
require "yajl"

module ACM::Controller

  class RackController
    PUBLIC_URLS = ["/info"]

    def initialize
      super
      @logger = ACM::Config.logger
      api_controller = ApiController.new

      @logger.debug("Created ApiController")

      @app = Rack::Auth::Basic.new(api_controller) do |username, password|
        [username, password] == [ACM::Config.basic_auth[:user], ACM::Config.basic_auth[:password]]
      end
      @app.realm = "ACM"

    end

    def call(env)

      @logger.debug("Received #{env["rack.url_scheme"].strip()} call " +
                    "from #{env["REMOTE_ADDR"].strip()} - #{env["HTTP_HOST"].strip()} " +
                    "operation #{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}#{env["QUERY_STRING"]}")

      start_time = Time.now
      status, headers, body = @app.call(env)
      end_time = Time.now
      @logger.debug("Completed #{env["rack.url_scheme"].strip()} call " +
                    "from #{env["REMOTE_ADDR"].strip()} - #{env["HTTP_HOST"].strip()} " +
                    "operation #{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}#{env["QUERY_STRING"]} " +
                    "Elapsed time #{end_time - start_time}ms")
      headers["Date"] = Time.now.rfc822 # As thin doesn't inject date

      @logger.debug("Sending response Status: #{status} Headers: #{headers} Body: #{body}")
      [ status, headers, body ]
    end

  end

end
