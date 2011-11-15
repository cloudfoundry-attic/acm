module ACM; module Controller; end; end

require "acm/config"
require "acm/api_controller"

require "sequel"
require "yajl"

module ACM

  module Controller

    class RackController
      PUBLIC_URLS = ["/info"]

      def initialize
        super
        @logger = Config.logger
      end

      def call(env)

        @logger.debug("Call with parameters #{env.inspect}")

        api_controller = ApiController.new

        @logger.debug("Created ApiController")

        app = Rack::Auth::Basic.new(api_controller) do |user, password|
          api_controller.authenticate(user, password)
        end
        app.realm = "ACM"

        status, headers, body = app.call(env)
        headers["Date"] = Time.now.rfc822 # As thin doesn't inject date

        [ status, headers, body ]
      end

    end

  end

end
