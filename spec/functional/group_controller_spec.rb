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

  describe "when sending an invalid request for group creation" do

    it "should respond with an error on an incorrectly formatted request" do
      @logger = ACM::Config.logger
      basic_authorize "admin", "password"

      post "/groups/#{SecureRandom.uuid}", { "CONTENT_TYPE" => "application/json", :input => "group_data" }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")

    end

    it "should respond with an error on an empty request" do
      @logger = ACM::Config.logger
      basic_authorize "admin", "password"

      post "/groups/#{SecureRandom.uuid}", {}, { "CONTENT_TYPE" => "application/json", :input => nil }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      body[:code].should eql(1001)
      body[:description].should include("Invalid request")

    end

  end

  describe "when creating a new group" do

    before(:each) do
      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)

      @group1 = SecureRandom.uuid

      @group_service = ACM::Services::GroupService.new()

    end

    it "should create the correct group" do
      basic_authorize "admin", "password"

      group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3, @user4]
      }

      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/groups/#{body[:id]}")

      body[:id].to_s.should eql(group_data[:id].to_s)
      body[:members].sort().should eql(group_data[:members].sort())
      body[:additional_info].should eql(group_data[:additional_info])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")

    end

    it "should not create a duplicate group" do
      basic_authorize "admin", "password"

      group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3, @user4]
      }

      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Location"].should be_nil

    end

    it "should not create group with the same id as a user" do
      basic_authorize "admin", "password"

      group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3, @user4]
      }

      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      group_data = {
        :id => @user1,
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3, @user4]
      }

      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(400)
      last_response.original_headers["Location"].should be_nil

    end

    it "should not add nil members to the group" do
      basic_authorize "admin", "password"

      group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [nil, nil]
      }

      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:id].to_s.should eql(group_data[:id].to_s)
      body[:members].should be_nil
      body[:additional_info].should eql(group_data[:additional_info])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")

    end

  end

  describe "when requesting a group" do

    before(:each) do
      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)

      @group1 = SecureRandom.uuid

      @group_service = ACM::Services::GroupService.new()

    end


    it "should return the group requested" do
      basic_authorize "admin", "password"

      group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3, @user4]
      }

      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      get "/groups/#{@group1}", {}, { "CONTENT_TYPE" => "application/json"}
      @logger.debug("get /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Location"].should be_nil

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:id].to_s.should eql(group_data[:id].to_s)
      body[:members].sort().should eql(group_data[:members].sort())
      body[:additional_info].should eql(group_data[:additional_info])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")

    end

    it "should return an error if the group does not exist" do
      basic_authorize "admin", "password"

      get "/groups/12345", {}, { "CONTENT_TYPE" => "application/json"}
      @logger.debug("get /groups last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end

  end

  describe "when deleting a group" do
    before(:each) do
      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)

      @group1 = SecureRandom.uuid

      @group_service = ACM::Services::GroupService.new()

      group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3]
      }

      basic_authorize "admin", "password"
      post "/groups/#{group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)


    end

    it "should delete the requested group successfully" do
      basic_authorize "admin", "password"

      delete "/groups/#{@group1}"
      @logger.debug("get /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Location"].should be_nil

    end

  end

  describe "when adding a user to a group" do

    before(:each) do
      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user5 = SecureRandom.uuid
      @user_service.create_user(:id => @user5)
      @user6 = SecureRandom.uuid
      @user_service.create_user(:id => @user6)

      @group1 = SecureRandom.uuid

      @group_service = ACM::Services::GroupService.new()

      @group1_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3]
      }

      basic_authorize "admin", "password"
      post "/groups/#{@group1_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => @group1_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      @group2 = SecureRandom.uuid

      group2_data = {
        :id => "g-#{@group2}",
        :additional_info => "Developer group",
        :members => [@user5, @user6]
      }

      basic_authorize "admin", "password"
      post "/groups/#{group2_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => group2_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

    end

    it "should not create a user that does not exist and return the updated group" do
      basic_authorize "admin", "password"

      put "/groups/#{@group1}/members/#{@user4}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(404)

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.status.should eql(404)

      error = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      error[:code].should eql(1000)
      error[:description].should include("not found")
    end

    it "should add the user to the group and return the updated group" do
      basic_authorize "admin", "password"

      put "/groups/#{@group1}/members/#{@user5}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/groups/#{body[:id]}")

      body[:id].to_s.should eql(@group1_data[:id].to_s)
      (body[:members].include? ("#{@user5}")).should be_true
      body[:additional_info].should eql(@group1_data[:additional_info])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should return an error if the group does not exist" do
      basic_authorize "admin", "password"

      new_group = SecureRandom.uuid
      put "/groups/#{new_group}/members/#{@user5}", {}, { "CONTENT_TYPE" => "application/json" }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(404)

      error = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should be_nil

      error[:code].should eql(1000)
      error[:description].should include("not found")
    end

  end

  describe "when updating a group" do

    before(:each) do
      @user_service = ACM::Services::UserService.new()
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user5 = SecureRandom.uuid
      @user_service.create_user(:id => @user5)
      @user6 = SecureRandom.uuid
      @user_service.create_user(:id => @user6)

      @group1 = SecureRandom.uuid

      @group_service = ACM::Services::GroupService.new()

      @group1_data = {
        :id => "g-#{@group1}",
        :additional_info => "Developer group",
        :members => [@user1, @user2, @user3]
      }

      basic_authorize "admin", "password"
      post "/groups/#{@group1_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => @group1_data.to_json() }
      @logger.debug("post /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

    end

    it "should be able to replace all the properties of the group" do
      basic_authorize "admin", "password"
      updated_group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Updated Developer group",
        :members => [@user5]
      }

      put "/groups/#{updated_group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_group_data.to_json() }
      @logger.debug("put /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/groups/#{body[:id]}")

      body[:id].to_s.should eql(@group1_data[:id].to_s)
      body[:members].should eql ([@user5])
      body[:additional_info].should eql(updated_group_data[:additional_info])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")

    end

    it "should be able to have an empty group" do
      basic_authorize "admin", "password"
      updated_group_data = {
        :id => "g-#{@group1}",
        :additional_info => "Updated Developer group"
      }

      put "/groups/#{updated_group_data[:id]}", {}, { "CONTENT_TYPE" => "application/json", :input => updated_group_data.to_json() }
      @logger.debug("put /groups last response #{last_response.inspect}")
      last_response.status.should eql(200)

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      last_response.original_headers["Location"].should eql("http://example.org/groups/#{body[:id]}")

      body[:id].to_s.should eql(@group1_data[:id].to_s)
      body[:members].should be_nil
      body[:additional_info].should eql(updated_group_data[:additional_info])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")

    end


  end

end
