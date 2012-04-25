#--
# Cloud Foundry 2012.02.03 Beta
# Copyright (c) [2009-2012] VMware, Inc. All Rights Reserved. 
# 
# This product is licensed to you under the Apache License, Version 2.0 (the "License").  
# You may not use this product except in compliance with the License.  
# 
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the 
# subcomponent's license, as noted in the LICENSE file. 
#++

require "acm/config"
require "acm/api_controller"

require "sequel"
require "yajl"

module ACM::Controller

  # Main application controller that receives all requests and passes them on to
  # the ApiController (Sinatra) for handling
  class ACMController

    def initialize
      super
      @logger = ACM::Config.logger
      api_controller = ApiController.new

      #Configure basic auth for all acm urls
      @app = Rack::Auth::Basic.new(api_controller) do |username, password|
        [username, password] == [ACM::Config.basic_auth[:user], ACM::Config.basic_auth[:password]]
      end
      @app.realm = "ACM"

      @logger.debug("Created ACMController")

    end

    # Rack requires the controller to respond to this message
    def call(env)
      @logger.debug("Request env #{env.inspect}")
      VCAP::Component.varz[:requests] += 1 unless VCAP::Component.varz.nil?
      request = Rack::Request.new(env)
      log_request(request)

      start_time = Time.now
      status, headers, body = @app.call(env)
      end_time = Time.now
      headers["Date"] = end_time.rfc822 # As thin doesn't inject date

      @logger.info("Sending response Status: #{status} Headers: #{headers} Body: #{body}")
      @logger.info("Elapsed time #{((end_time - start_time) * 1000.0).to_i} ms")
      [ status, headers, body ]
    end

    def log_request(request)
      method = request.request_method
      url = request.url
      params = request.params if request.params
      body_size = "body size #{request.body.size}" if request.body
      @logger.info("Incoming request #{method} #{url} #{params} #{body_size}")
    end

  end

end
