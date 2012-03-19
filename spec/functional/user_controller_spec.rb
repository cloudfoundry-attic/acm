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
    @app ||= ACM::Controller::ACMController.new
  end

  describe "creating a user" do 
    before(:each) do
      @logger = ACM::Config.logger
    end

    it "should create a user with the correct id" do
      basic_authorize "admin", "password"

      user_id = SecureRandom.uuid

      post "/users/#{user_id}"
      @logger.debug("post /users/#{user_id} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(user_id)
      user[:groups].should be_nil
    end

  end

  describe "getting user information" do

    before(:each) do
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

      @group_service = ACM::Services::GroupService.new()
      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user3, @user4, @user8])


      group_json = @group_service.create_group(:id => @group2,
                                              :additional_info => "Another developer group",
                                              :members => [@user5, @user6, @user7, @user8])

      @object_service = ACM::Services::ObjectService.new()
      o_json = @object_service.create_object(:name => "www_staging_1",
                                      :additional_info => {:description => :staging_app_space}.to_json(),
                                      :permission_sets => [:app_space],
                                      :acl => {
                                        :read_appspace => ["#{@user1}", "#{@user3}", "#{@user4}", "g-#{@group2}"],
                                        :write_appspace => ["#{@user3}", "g-#{@group1}"],
                                        :delete_appspace => ["#{@user4}"]
                                      })
      @object1 = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      o_json = @object_service.create_object(:name => "www_staging_2",
                                      :additional_info => {:description => :staging_app_space}.to_json(),
                                      :permission_sets => [:app_space],
                                      :acl => {
                                        :write_appspace => ["g-#{@group2}"],
                                        :delete_appspace => ["#{@user1}"]
                                      })
      @object2 = Yajl::Parser.parse(o_json, :symbolize_keys => true)

    end

    it "should fetch the user information containing the id, groups and objects" do
      basic_authorize "admin", "password"

      get "/users/#{@user1}"
      @logger.debug("get /users/#{@user1} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(@user1)
      user[:groups].should be_nil
      user[:objects].sort().should eql([@object2[:id], @object1[:id]].sort())

      get "/users/#{@user3}"
      @logger.debug("get /users/#{@user3} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(@user3)
      user[:groups].sort().should eql([@group1].sort())
      user[:objects].sort().should eql([@object1[:id]].sort())

      get "/users/#{@user4}"
      @logger.debug("get /users/#{@user4} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(@user4)
      user[:groups].sort().should eql([@group1].sort())
      user[:objects].sort().should eql([@object1[:id]].sort())

      get "/users/#{@user5}"
      @logger.debug("get /users/#{@user5} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(@user5)
      user[:groups].sort().should eql([@group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())

      get "/users/#{@user6}"
      @logger.debug("get /users/#{@user6} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(@user6)
      user[:groups].sort().should eql([@group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())

      get "/users/#{@user7}"
      @logger.debug("get /users/#{@user7} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(@user7)
      user[:groups].sort().should eql([@group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())

      get "/users/#{@user8}"
      @logger.debug("get /users/#{@user8} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should_not eql("0")
      user = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)
      user[:id].should eql(@user8)
      user[:groups].sort().should eql([@group1, @group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())
    end

    it "should raise an error if the user id cannot be found" do
      basic_authorize "admin", "password"

      new_user = SecureRandom.uuid
      get "/users/#{new_user}"
      @logger.debug("get /users/#{new_user} last response #{last_response.inspect}")
      last_response.status.should eql(404)

    end

  end

  describe "deleting a user" do

    before(:each) do
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

      @group_service = ACM::Services::GroupService.new()
      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user3, @user4, @user8])


      group_json = @group_service.create_group(:id => @group2,
                                              :additional_info => "Another developer group",
                                              :members => [@user5, @user6, @user7, @user8])

      @object_service = ACM::Services::ObjectService.new()
      o_json = @object_service.create_object(:name => "www_staging_1",
                                      :additional_info => {:description => :staging_app_space}.to_json(),
                                      :permission_sets => [:app_space],
                                      :acl => {
                                        :read_appspace => ["#{@user1}", "#{@user3}", "#{@user4}", "g-#{@group2}"],
                                        :write_appspace => ["#{@user3}", "g-#{@group1}"],
                                        :delete_appspace => ["#{@user4}"]
                                      })
      @object1 = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      o_json = @object_service.create_object(:name => "www_staging_2",
                                      :additional_info => {:description => :staging_app_space}.to_json(),
                                      :permission_sets => [:app_space],
                                      :acl => {
                                        :write_appspace => ["g-#{@group2}"],
                                        :delete_appspace => ["#{@user1}"]
                                      })
      @object2 = Yajl::Parser.parse(o_json, :symbolize_keys => true)

    end

    it "should fetch the user information containing the id, groups and objects" do
      basic_authorize "admin", "password"

      delete "/users/#{@user8}"
      @logger.debug("delete /users/#{@user8} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should eql("0")

      updated_group = Yajl::Parser.parse(@group_service.find_group("g-#{@group1}"))
      updated_group[:members.to_s].sort.should eql([@user3, @user4].sort)

      delete "/users/#{@user1}"
      @logger.debug("delete /users/#{@user8} last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8, schema=urn:acm:schemas:1.0")
      last_response.original_headers["Content-Length"].should eql("0")

      updated_group = Yajl::Parser.parse(@group_service.find_group("g-#{@group2}"))
      updated_group[:members.to_s].sort.should eql([@user5, @user6, @user7].sort)
    end

    it "should raise an error if the user id cannot be found" do
      basic_authorize "admin", "password"

      new_user = SecureRandom.uuid
      delete "/users/#{new_user}"
      @logger.debug("delete /users/#{new_user} last response #{last_response.inspect}")
      last_response.status.should eql(404)
    end

  end

end
