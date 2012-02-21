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

require 'sinatra/base'

module ACM::Controller

  class ApiController < Sinatra::Base

    post '/users/:user_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("POST request for /users/#{params[:user_id]}")

      response = @user_service.create_user(:id => params[:user_id])
      @logger.debug("Response is #{response.inspect}")

      response
    end

    get '/users/:user_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("GET request for /users/#{params[:user_id]}")

      response = @user_service.get_user_info(params[:user_id])
      @logger.debug("Response is #{response.inspect}")

      response
    end

  end

end
