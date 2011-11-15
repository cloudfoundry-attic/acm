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

        #if perform_auth?(env)
        #  app = Rack::Auth::Basic.new(api_controller) do |user, password|
        #    api_controller.authenticate(user, password)
        #  end
        #
        #  app.realm = "Collab Spaces"
        #else
          app = api_controller
        #end

        status, headers, body = app.call(env)
        headers["Date"] = Time.now.rfc822 # As thin doesn't inject date

        [ status, headers, body ]
      end


      #TODO: Need to modify this for the UAA
      def perform_auth?(env)
        auth_needed   = !PUBLIC_URLS.include?(env["PATH_INFO"])
        auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect{ |key| env.has_key?(key) }
        auth_needed || auth_provided
      end
    end

  end

end
