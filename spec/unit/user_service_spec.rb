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

require 'acm/services/user_service'
require 'json'

describe ACM::Services::UserService do

  before(:each) do
    @user_service = ACM::Services::UserService.new()
  end

  describe "creating a user" do

    it "will create a user without an id and assign one to it" do

      user_information = @user_service.create_user(:additional_info => {:email => "olds@vmware.com"}.to_json())

      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)

      user[:id].should_not be_nil
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

    end

    it "will create a user with an id" do

      user_information = @user_service.create_user(:id => "abc12345", :additional_info => {:email => "olds@vmware.com"}.to_json())

      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)

      user[:id].should eql("abc12345")
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

    end

    it "will not allow you to create any other type of subject" do

      user_information = @user_service.create_user(:additional_info => {:email => "olds@vmware.com"}.to_json(), :type => "random")

      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)

      user[:id].should_not be_nil
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

    end

    it "will not create a duplicate id" do

      user_information = @user_service.create_user(:id => "abc12345", :additional_info => {:email => "olds@vmware.com"}.to_json())

      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)

      user[:id].should eql("abc12345")
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

      lambda {
        user_information = @user_service.create_user(:id => "abc12345", :additional_info => {:email => "olds@vmware.com"}.to_json())
      }.should raise_error(ACM::InvalidRequest)

    end

  end

  describe "getting user information" do
    before (:each) do
      @logger = ACM::Config.logger

      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                  :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                  :additional_info => "this is the permission set for the app space")
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

      user_information = @user_service.get_user_info(@user1)
      @logger.debug("user information #{user_information}")
      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)
      user[:id].should eql(@user1)
      user[:groups].should be_nil
      user[:objects].sort().should eql([@object2[:id], @object1[:id]].sort())

      user_information = @user_service.get_user_info(@user3)
      @logger.debug("user information #{user_information}")
      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)
      user[:id].should eql(@user3)
      user[:groups].sort().should eql([@group1].sort())
      user[:objects].sort().should eql([@object1[:id]].sort())

      user_information = @user_service.get_user_info(@user4)
      @logger.debug("user information #{user_information}")
      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)
      user[:id].should eql(@user4)
      user[:groups].sort().should eql([@group1].sort())
      user[:objects].sort().should eql([@object1[:id]].sort())

      user_information = @user_service.get_user_info(@user5)
      @logger.debug("user information #{user_information}")
      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)
      user[:id].should eql(@user5)
      user[:groups].sort().should eql([@group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())

      user_information = @user_service.get_user_info(@user6)
      @logger.debug("user information #{user_information}")
      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)
      user[:id].should eql(@user6)
      user[:groups].sort().should eql([@group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())

      user_information = @user_service.get_user_info(@user7)
      @logger.debug("user information #{user_information}")
      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)
      user[:id].should eql(@user7)
      user[:groups].sort().should eql([@group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())

      user_information = @user_service.get_user_info(@user8)
      @logger.debug("user information #{user_information}")
      user = Yajl::Parser.parse(user_information, :symbolize_keys => true)
      user[:id].should eql(@user8)
      user[:groups].sort().should eql([@group1, @group2].sort())
      user[:objects].sort().should eql([@object1[:id], @object2[:id]].sort())
    end

    it "should raise an error if the user id cannot be found" do
      new_user = SecureRandom.uuid
      lambda {
        user_information = @user_service.get_user_info(new_user)
      }.should raise_error(ACM::ObjectNotFound)

    end

  end

  describe "deleting users" do
    before (:each) do
      @logger = ACM::Config.logger

      @permission_set_service = ACM::Services::PermissionSetService.new()

      @permission_set_service.create_permission_set(:name => :app_space,
                                                  :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                  :additional_info => "this is the permission set for the app space")
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


      group_json = @group_service.create_group(:id => "g-#{@group2}",
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

    it "clean up all references to that user" do

      @user_service.delete_user(@user8)

      updated_group = Yajl::Parser.parse(@group_service.find_group("g-#{@group1}"))
      updated_group[:members.to_s].sort.should eql([@user3, @user4].sort)

      updated_group = Yajl::Parser.parse(@group_service.find_group("g-#{@group2}"))
      updated_group[:members.to_s].sort.should eql([@user5, @user6, @user7].sort)


      @user_service.delete_user(@user1)
      updated_object = Yajl::Parser.parse(@object_service.read_object(@object1[:id]), :symbolize_keys => true)
      updated_object[:acl][:read_appspace].sort.should eql(["#{@user3}", "#{@user4}", "g-#{@group2}"].sort)
      updated_object = Yajl::Parser.parse(@object_service.read_object(@object2[:id]), :symbolize_keys => true)
      updated_object[:acl][:delete_appspace].should be_nil
    end

    it "should raise an error if the user id cannot be found" do
      new_user = SecureRandom.uuid
      lambda {
        @user_service.delete_user(new_user)
      }.should raise_error(ACM::ObjectNotFound)

    end

  end


end
