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
require "json"

describe ACM::Controller::ApiController do
  include Rack::Test::Methods

  def app
    @app ||= ACM::Controller::RackController.new
  end


  before(:each) do
    @logger = ACM::Config.logger
  end

  describe "when sending an invalid request for object creation" do

    it "should respond with an error on an incorrectly formatted request" do
      
      basic_authorize "admin", "password"

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => "object_data" }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")

    end

    it "should respond with an error on an empty request" do
      
      basic_authorize "admin", "password"

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => nil }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")

    end


  end


  describe "when requesting a new object" do

    before(:each) do
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                    :additional_info => "this is the permission set for the app space")

      @permission_set_service.create_permission_set(:name => :director)

      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)

      @group_service = ACM::Services::GroupService.new()

      
    end

    it "should create a new object and return it's representation" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :id => "54947df8-0e9e-4471-a2f9-9af509fb5889",
        :additional_info => "{component => cloud_controller}",
        :meta => {
          :updated => 1273740902,
          :created => 1273726800,
          :schema => "urn:acm:schemas:1.0"
        }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should eql(object_data[:permission_sets])
      body[:additional_info].should eql(object_data[:additional_info])
      body[:id].should_not be_nil
      body[:id].should_not eql(object_data[:id])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:created].should_not eql(object_data[:meta][:created])
      body[:meta][:updated].should_not eql(object_data[:meta][:updated])
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should create an object with multiple types"

    it "should create an object with no types" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :additional_info => "{component => cloud_controller}"
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should be_nil
      body[:additional_info].should eql(object_data[:additional_info])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should assign the requested acls to a new object" do
      basic_authorize "admin", "password"
      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)
      @user5 = SecureRandom.uuid
      @user_service.create_user(:id => @user5)
      @user6 = SecureRandom.uuid
      @user_service.create_user(:id => @user6)

      @group1 = SecureRandom.uuid
      @group_service.create_group(:id => @group1, :members => [@user1])
      @group2 = SecureRandom.uuid
      @group_service.create_group(:id => @group2)
      @group3 = SecureRandom.uuid
      @group_service.create_group(:id => @group3)
      @group4 = SecureRandom.uuid
      @group_service.create_group(:id => @group4, :members => [@user4, @user5, @user6])

      object_data = {
        :name => "www_staging",
        :additional_info => {:description => :staging_app_space}.to_json(),
        :permission_sets => [:app_space.to_s],
        :acl => {
            :read_appspace => ["g-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"],
            :write_appspace => ["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"],
            :delete_appspace => ["u-#{@user2}", "u-#{@user5}", "g-#{@group3}"]
        }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      body[:acl].should_not be_nil
      sorted_acls = body[:acl].keys().sort()
      sorted_acls.should eql([:read_appspace, :write_appspace, :delete_appspace].sort())

      sorted_users = body[:acl][:read_appspace].sort()
      sorted_users.should eql(["g-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"].sort())

      sorted_users = body[:acl][:write_appspace].sort()
      sorted_users.should eql(["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"].sort())

      sorted_users = body[:acl][:delete_appspace].sort()
      sorted_users.should eql(["u-#{@user2}", "u-#{@user5}", "g-#{@group3}"].sort())

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should eql(object_data[:permission_sets])
      body[:additional_info].should eql(object_data[:additional_info])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should assign the requested groups to a new object" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      body[:acl].should_not be_nil
      sorted_acls = body[:acl].keys().sort()
      sorted_acls.should eql([:read_appspace, :write_appspace, :delete_appspace].sort())

      sorted_users = body[:acl][:read_appspace].sort()
      sorted_users.should eql(["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"].sort())

      sorted_users = body[:acl][:write_appspace].sort()
      sorted_users.should eql(["u-#{@user2}", "u-#{@user3}"].sort())

      sorted_users = body[:acl][:delete_appspace].sort()
      sorted_users.should eql(["u-#{@user4}"].sort())

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should eql(object_data[:permission_sets])
      body[:additional_info].should eql(object_data[:additional_info])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should not allow a permission to be assigned to an object with no types" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")
    end


    it "should assign a permission to an object only if the type allows it" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :update_appspace => ["u-#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")
    end

  end

  describe "when fetching an object" do

    before(:each) do
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                    :additional_info => "this is the permission set for the app space")

      @permission_set_service.create_permission_set(:name => :director)


      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)

      
    end

    it "should return the object that's requested" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      original_object = last_response.body

      get "/objects/#{body[:id]}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{body[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      fetched_object = last_response.body
      last_response.original_headers["Location"].should be_nil

      original_object.should eql(fetched_object)

    end

    it "should return an error when the object does not exist" do
      basic_authorize "admin", "password"

      get "/objects/1234", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

    it "should return an error on an invalid request" do
      basic_authorize "admin", "password"

      get "/objects/", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

  end

  describe "when deleting an object" do

    before(:each) do
      #Fix the schema
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                    :additional_info => "this is the permission set for the app space")

      @permission_set_service.create_permission_set(:name => :director)


      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)

      
    end

    it "should delete the object that's requested" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      delete "/objects/#{body[:id]}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{body[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should eql("0")

      get "/objects/#{body[:id]}", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1000)
      body[:description].should include("not found")

      #Should not mess up any other tables. should be able to still create objects
      object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      body[:acl].should_not be_nil
      sorted_acls = body[:acl].keys().sort()
      sorted_acls.should eql([:read_appspace, :write_appspace, :delete_appspace].sort())

      sorted_users = body[:acl][:read_appspace].sort()
      sorted_users.should eql(["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"].sort())

      sorted_users = body[:acl][:write_appspace].sort()
      sorted_users.should eql(["u-#{@user2}", "u-#{@user3}"].sort())

      sorted_users = body[:acl][:delete_appspace].sort()
      sorted_users.should eql(["u-#{@user4}"].sort())

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:permission_sets].should eql(object_data[:permission_sets])
      body[:additional_info].should eql(object_data[:additional_info])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")

    end

    it "should return an error when the object does not exist" do
      basic_authorize "admin", "password"

      delete "/objects/1234", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

    it "should return an error on an invalid request" do
      basic_authorize "admin", "password"

      delete "/objects/", {}, { "CONTENT_TYPE" => "application/json" }
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

  end

  describe "getting user information for an object" do

    before (:each) do
      
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

    it "should return all the users of an object with their associated permissions" do

      get "/objects/#{@object[:id]}/users", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("get /objects/#{@object[:id]}/users last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      user_permission_map = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      user_permission_map.size().should eql(7)

      user_permission_map[@user1.to_sym].sort().should eql([:read_appspace.to_s].sort())
      user_permission_map[@user2.to_sym].sort().should eql([:read_appspace.to_s, :write_appspace.to_s].sort())
      user_permission_map[@user3.to_sym].sort().should eql([:read_appspace.to_s, :write_appspace.to_s].sort())
      user_permission_map[@user4.to_sym].sort().should eql([:read_appspace.to_s, :write_appspace.to_s, :delete_appspace.to_s].sort())
      user_permission_map[@user5.to_sym].sort().should eql([:read_appspace.to_s].sort())
      user_permission_map[@user6.to_sym].sort().should eql([:read_appspace.to_s].sort())
      user_permission_map[@user7.to_sym].sort().should eql([:read_appspace.to_s].sort())
    end

  end

  describe "when updating an acl" do

    before (:each) do
      
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace, :add_app_to_appspace, :remove_app_from_appspace],
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
        :write_appspace => ["u-#{@user2}", "g-#{@group1}"]
         }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      @object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

    end

    it "should return an object with a new ace for a permission that does not exist in the object" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=u-#{@user4}&p=delete_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=u-#{@user4}&p=delete_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:delete_appspace].include? ("u-#{@user4}")).should be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end

    it "should return an object with a new ace for a set of permissions that do not exist in the object" do
      basic_authorize "admin", "password"

      delete "/objects/#{@object[:id]}/acl?id=u-#{@user2}&p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{@object[:id]}/acl?id=u-#{@user2}&p=read_appspace,write_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("u-#{@user2}")).should_not be_true
      (updated_object[:acl][:write_appspace].include? ("u-#{@user2}")).should_not be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additionalInfo].should eql(@object[:additionalInfo])
   end

   it "should remove an ace for a subject when a permission has been deleted" do
      basic_authorize "admin", "password"

      delete "/objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("u-#{@user1}")).should_not be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additionalInfo].should eql(@object[:additionalInfo])
    end

    it "should remove the required aces for a subject when a set of permission has been deleted" do
      basic_authorize "admin", "password"

      delete "/objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("u-#{@user1}")).should_not be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
   end

   it "should remove an ace for a subject when a permission has been deleted" do
      basic_authorize "admin", "password"

      delete "/objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("u-#{@user1}")).should_not be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end

    it "should remove the required aces for a subject when a set of permission has been deleted" do
      basic_authorize "admin", "password"

      delete "/objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("u-#{@user1}")).should_not be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end


    it "should return an error when trying to remove a non-existent permission" do
      basic_authorize "admin", "password"

      delete "/objects/#{@object[:id]}/acl?id=u-#{@user4}&p=delete_appspace,add_app_to_appspace,remove_app_from_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("delete /objects/#{@object[:id]}/acl?id=u-#{@user4}&p=delete_appspace,add_app_to_appspace,remove_app_from_appspace last response #{last_response.inspect}")

      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Could not find an access control entry")
   end

   it "should return an object with an updated ace for a permission that exists in the object" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=u-#{@user4}&p=write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=u-#{@user4}&p=write_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:write_appspace].include? ("u-#{@user4}")).should be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end

   it "should return an object with an updated ace for a set of permissions that exists on the object" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=u-#{@user7}&p=read_appspace,write_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=u-#{@user7}&p=read_appspace,write_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:write_appspace].include? ("u-#{@user7}")).should be_true
      (updated_object[:acl][:read_appspace].include? ("u-#{@user7}")).should be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end


    it "should not return the same user twice in the ace if it already exists" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("u-#{@user1}")).should be_true
      updated_object[:acl][:read_appspace].size().should eql(@object[:acl][:read_appspace].size())
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end

    it "should return an error for a permission that is not in the permission set" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=u-#{@user1}&p=clobber_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=u-#{@user1}&p=clobber_appspace last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      error = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      error[:code].should eql(1001)
      error[:description].should include("Invalid request")
    end

    it "should return an error if a single permission is not in the permission set" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace,clobber_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=u-#{@user1}&p=read_appspace,clobber_appspace last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      error = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      error[:code].should eql(1001)
      error[:description].should include("Invalid request")
    end


    it "should return an error for an object that does not exist" do
      basic_authorize "admin", "password"

      new_object_id = SecureRandom.uuid
      put "/objects/#{new_object_id}/acl?id=u-#{@user1}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{new_object_id}/acl?id=u-#{@user1}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      error = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      error[:code].should eql(1000)
      error[:description].should include("not found")
    end

    it "should not create a user that does not exist and instead return ane error" do
      basic_authorize "admin", "password"

      new_user = SecureRandom.uuid
      put "/objects/#{@object[:id]}/acl?id=u-#{new_user}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=u-#{new_user}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(404)
      last_response.original_headers["Location"].should be_nil

      error = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      error[:code].should eql(1000)
      error[:description].should include("not found")
    end

    it "should update the object if the subject is a group that exists" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=g-#{@group1}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=g-#{@group1}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("g-#{@group1}")).should be_true
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end

    it "should update the object if the subject is a group that exists and already has the same permission" do
      basic_authorize "admin", "password"

      put "/objects/#{@object[:id]}/acl?id=g-#{@group2}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=g-#{@group2}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      updated_object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{updated_object[:id]}")

      (updated_object[:acl][:read_appspace].include? ("g-#{@group2}")).should be_true
      updated_object[:acl][:read_appspace].size().should eql(@object[:acl][:read_appspace].size())
      updated_object[:id].should eql(@object[:id])
      updated_object[:permission_sets].should eql(@object[:permission_sets])
      updated_object[:additional_info].should eql(@object[:additional_info])
    end

    it "should return an error if the subject is a group that does not exist" do
      basic_authorize "admin", "password"

      new_group = SecureRandom.uuid
      put "/objects/#{@object[:id]}/acl?id=g-#{new_group}&p=read_appspace", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]}/acl?id=g-#{new_group}&p=read_appspace last response #{last_response.inspect}")
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      error = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      error[:code].should eql(1000)
      error[:description].should include("not found")
    end

  end

  describe "when updating an existing object" do

    before(:each) do
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :advanced_app_space,
                                                    :permissions => [:read_appspace_log, :destroy_appspace],
                                                    :additional_info => "this is the permission set for the app space")

      @permission_set_service.create_permission_set(:name => :app_space,
                                                    :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                    :additional_info => "this is the permission set for the app space")

      @permission_set_service.create_permission_set(:name => :director)

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

      @group_service = ACM::Services::GroupService.new()

      @group1 = SecureRandom.uuid
      @group2 = SecureRandom.uuid
      @group3 = SecureRandom.uuid
      @group4 = SecureRandom.uuid

      @group_service.create_group(:id => @group1, :members => [@user1])
      @group_service.create_group(:id => @group2, :members => [@user1, @user3])
      @group_service.create_group(:id => @group3, :members => [@user2, @user5])
      @group_service.create_group(:id => @group4, :members => [@user3, @user6, @user1])

      basic_authorize "admin", "password"

      @object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
            :read_appspace => ["g-#{@group1}", "u-#{@user1}", "u-#{@user6}"],
            :write_appspace => ["g-#{@group1}", "g-#{@group4}"],
            :delete_appspace => ["u-#{@user2}"]
        }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => @object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      @object = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      
    end

    it "should update the object and return it's representation" do
      sleep(1)

      updated_object_data = {
        :name => "updated_www_staging",
        :permission_sets => ["advanced_app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
            :read_appspace_log => ["g-#{@group1}", "u-#{@user1}", "u-#{@user6}"],
            :destroy_appspace => ["g-#{@group1}", "g-#{@group4}", "u-#{@user2}"]
        }
      }

      put "/objects/#{@object[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_object_data.to_json() }
      @logger.debug("post /objects/#{@object[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{@object[:id]}")

      body[:name].to_s.should eql(updated_object_data[:name].to_s)
      body[:permission_sets].should eql(updated_object_data[:permission_sets])
      body[:additional_info].should eql(updated_object_data[:additional_info])
      body[:id].should eql(@object[:id])
      body[:acl][:read_appspace_log].sort().should eql(["g-#{@group1}", "u-#{@user1}", "u-#{@user6}"].sort())
      body[:acl][:destroy_appspace].sort().should eql(["g-#{@group1}", "g-#{@group4}", "u-#{@user2}"].sort())
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:created].should eql(@object[:meta][:created])
      (Time.parse(body[:meta][:updated]) > Time.parse(@object[:meta][:updated])).should be_true
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should update an object to one with no types" do
      sleep(1)

      updated_object_data = {
        :name => "www_staging",
        :additional_info => "{component => cloud_controller}"
      }

      put "/objects/#{@object[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_object_data.to_json() }
      @logger.debug("put /objects/#{@object[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{@object[:id]}")

      body[:name].to_s.should eql(updated_object_data[:name].to_s)
      body[:permission_sets].should be_nil
      body[:additional_info].should eql(updated_object_data[:additional_info])
      body[:id].should eql(@object[:id])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:created].should eql(@object[:meta][:created])
      (Time.parse(body[:meta][:updated]) > Time.parse(@object[:meta][:updated])).should be_true
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should assign the requested acls to an updated object" do
      sleep(1)

      updated_object_data = {
        :name => "www_staging",
        :additional_info => {:description => :staging_app_space}.to_json(),
        :permission_sets => [:app_space.to_s],
        :acl => {
            :write_appspace => ["g-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"],
            :read_appspace => ["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"],
            :delete_appspace => ["u-#{@user2}", "g-#{@group3}"]
        }
      }

      put "/objects/#{@object[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_object_data.to_json() }
      @logger.debug("put /objects/#{@object[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      body[:acl].should_not be_nil
      sorted_acls = body[:acl].keys().sort()
      sorted_acls.should eql([:read_appspace, :write_appspace, :delete_appspace].sort())

      sorted_users = body[:acl][:write_appspace].sort()
      sorted_users.should eql(["g-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"].sort())

      sorted_users = body[:acl][:read_appspace].sort()
      sorted_users.should eql(["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"].sort())

      sorted_users = body[:acl][:delete_appspace].sort()
      sorted_users.should eql(["u-#{@user2}", "g-#{@group3}"].sort())

      body[:name].to_s.should eql(updated_object_data[:name].to_s)
      body[:permission_sets].should eql(updated_object_data[:permission_sets])
      body[:additional_info].should eql(updated_object_data[:additional_info])
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:created].should eql(@object[:meta][:created])
      (Time.parse(body[:meta][:updated]) > Time.parse(@object[:meta][:updated])).should be_true
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should be able to remove all the properties of an object" do
      sleep(1)

      put "/objects/#{@object[:id]}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("put /objects/#{@object[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/objects/#{body[:id]}")

      body[:acl].should eql({})
      body[:name].should be_nil
      body[:permission_sets].should be_nil
      body[:additional_info].should be_nil
      body[:id].should_not be_nil
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:created].should eql(@object[:meta][:created])
      @logger.debug("BODY #{body.inspect} OBJECT #{@object.inspect}")
      (Time.parse(body[:meta][:updated]) > Time.parse(@object[:meta][:updated])).should be_true
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should not allow an update of an object that does not exist" do
      basic_authorize "admin", "password"

      updated_object_data = {
        :name => "www_staging",
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      put "/objects/#{1234}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_object_data.to_json() }
      @logger.debug("put /objects/1234 last response #{last_response.inspect}")
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end

    it "should not allow a permission to be assigned to an object with no types" do
      basic_authorize "admin", "password"

      updated_object_data = {
        :name => "www_staging",
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :delete_appspace => ["u-#{@user4}"]
         }
      }

      put "/objects/#{@object[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_object_data.to_json() }
      @logger.debug("put /objects/#{@object[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")
    end

    it "should assign a permission to an object only if the type allows it" do
      basic_authorize "admin", "password"

      updated_object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :update_appspace => ["u-#{@user4}"]
         }
      }

      put "/objects/#{@object[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_object_data.to_json() }
      @logger.debug("put /objects/#{@object[:id]} last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")
    end

    it "should error out if the object id is not present" do
      basic_authorize "admin", "password"

      updated_object_data = {
        :name => "www_staging",
        :permission_sets => ["app_space"],
        :additional_info => "{component => cloud_controller}",
        :acl => {
          :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
          :write_appspace => ["u-#{@user2}", "u-#{@user3}"],
          :update_appspace => ["u-#{@user4}"]
         }
      }

      put "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => updated_object_data.to_json() }
      @logger.debug("put /objects last response #{last_response.inspect}")
      last_response.status.should eql(404)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1000)
      body[:description].should include("not found")
    end


  end

end
