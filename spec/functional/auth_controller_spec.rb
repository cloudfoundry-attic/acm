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

require File.expand_path("../../spec_helper", __FILE__)

require "rack/test"

describe ACM::Controller::RackController do
  include Rack::Test::Methods

  before(:each) do
    @logger = ACM::Config.logger
  end

  def app
    @app ||= ACM::Controller::RackController.new
  end

  describe "api authentication" do

    it "requires auth" do
      get "/"
      last_response.status.should eql(401)
      @logger.debug("Auth response #{last_response.inspect}")
    end

    it "allows correct credentials" do
      basic_authorize "admin", "password"
      get "/"
      @logger.debug("Auth response #{last_response.inspect}")
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      body[:code].should eql(1000)
      body[:description].should eql("The object was not found")
    end

    it "should not allow incorrect credentials" do
      basic_authorize "admin", "password1234"
      get "/"
      last_response.status.should eql(401)
      @logger.debug("Auth response #{last_response.inspect}")
    end

  end

end
