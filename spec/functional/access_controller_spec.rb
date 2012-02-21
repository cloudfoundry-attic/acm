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

describe ACM::Controller::ApiController do
  include Rack::Test::Methods
  alias_method :old_get, :get

  def get(uri, params = {}, env = {}, &block)
    old_get(uri, params = {}, env = {}, &block)
    @logger.debug("REQUEST #{last_request.inspect}")
  end

  def app
    @app ||= ACM::Controller::RackController.new
  end

  describe "check access" do

    before (:each) do
      @logger = ACM::Config.logger
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                    :additional_info => "this is the permission set for the app space")
      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)
      @user5 = SecureRandom.uuid
      @user_service.create_user(:id => @user5)
      @user6 = SecureRandom.uuid
      @user_service.create_user(:id => @user6)
      @user7 = SecureRandom.uuid
      @user_service.create_user(:id => @user7)
      @user8 = SecureRandom.uuid
      @user_service.create_user(:id => @user8)


      @group1 = SecureRandom.uuid
      @group2 = SecureRandom.uuid

      basic_authorize "admin", "password"

      group_data = {
        :id => @group1,
        :additional_info => "Developer group",
        :members => [@user3, @user4]
      }

      post "/groups", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      group_data = {
        :id => @group2,
        :additional_info => "Developer group",
        :members => [@user5, @user6, @user7]
      }

      post "/groups", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}", "g-#{@group2}"],
          :write_appspace => ["u-#{@user2}", "g-#{@group1}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      @object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

    end

    it "will return a 200 if access is granted" do
      get "/objects/#{@object[:id]}/access?id=#{@user2}&p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(200)

    end

    it "will return a 200 if access is granted for a group" do
      get "/objects/#{@object[:id]}/access?id=#{@group1}&p=write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(200)

    end

    it "will return a 200 if access is granted for a member of a group" do
      get "/objects/#{@object[:id]}/access?id=#{@user7}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(200)

    end

    it "will return a 400 for an empty subject" do
      get "/objects/#{@object[:id]}/access?p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(400)

    end

    it "will return a 400 for no permissions" do
      get "/objects/#{@object[:id]}/access?id=#{@user1}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(400)

    end

    it "will return a 400 for no subject or permissions" do
      get "/objects/#{@object[:id]}/access", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(400)

    end

    it "will return a 404 for permissions that do not exist" do
      get "/objects/#{@object[:id]}/access?id=#{@user2}&p=read_appspace,some_random_permission", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end

    it "will return a 404 if there are existing permissions that do not apply to this user" do
      get "/objects/#{@object[:id]}/access?id=#{@user2}&p=read_appspace,delete_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end

    it "will return a 404 for an object that does not exist" do
      get "/objects/12345/access?id=#{@user1}&p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/12345/access last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end

    it "will return a 404 for a user that does not exist" do
      get "/objects/#{@object[:id]}/access?id=55555&p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end

    it "will return a 404 if the user is in one ace but not the other" do
      get "/objects/#{@object[:id]}/access?id=#{@user1}&p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end

    it "will return a 404 if the user is in neither of the aces" do
      get "/objects/#{@object[:id]}/access?id=44444&p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/access last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end


  end

end
