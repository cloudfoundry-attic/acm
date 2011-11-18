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

      @logger.debug("Call with parameters #{env.inspect}")

      status, headers, body = @app.call(env)
      headers["Date"] = Time.now.rfc822 # As thin doesn't inject date

      [ status, headers, body ]
    end

  end

end
