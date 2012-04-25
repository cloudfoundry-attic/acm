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

require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/group_service'
require 'yajl'

describe ACM::Services::GroupService do

  before(:each) do

    @user_service = ACM::Services::UserService.new()
    @group_service = ACM::Services::GroupService.new()

    @group1 = SecureRandom.uuid

    @user1 = SecureRandom.uuid
    @user_service.create_user(:id => @user1)
    @user2 = SecureRandom.uuid
    @user_service.create_user(:id => @user2)
    @user3 = SecureRandom.uuid
    @user_service.create_user(:id => @user3)
    @user4 = SecureRandom.uuid
    @user_service.create_user(:id => @user4)

    @logger = ACM::Config.logger
  end

  describe "creating a group" do

    it "should create an empty group given a unique id" do

      group_json = @group_service.create_group(:id => "g-#{@group1}", :additional_info => "Developer group")

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group[:id].should eql("g-#{@group1}")
      group[:members].should be_nil
      group[:additional_info].should eql("Developer group")

      group[:meta][:created].should_not be_nil
      group[:meta][:updated].should_not be_nil

    end

    it "should create a group correctly given a unique id and a set of members" do

      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group[:id].should eql("g-#{@group1}")
      group[:members].sort().should eql([@user1, @user2, @user3, @user4].sort())
      group[:additional_info].should eql("Developer group")

      group[:meta][:created].should_not be_nil
      group[:meta][:updated].should_not be_nil

    end

    it "should be possible to create a group without an id" do

      group_json = @group_service.create_group()

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group[:id].should_not be_nil
      group[:members].should be_nil
      group[:additional_info].should be_nil

      group[:meta][:created].should_not be_nil
      group[:meta][:updated].should_not be_nil

    end

    it "should not be possible to create a group with an existing name" do

      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])

      lambda {
        group_json = @group_service.create_group(:id => "g-#{@group1}")
      }.should raise_error(ACM::InvalidRequest)

    end

  end

  describe "fetching a group" do

    it "should return the group requested" do

      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      fetched_group_json = @group_service.find_group(group[:id])
      fetched_group = Yajl::Parser.parse(fetched_group_json, :symbolize_keys => true)

      fetched_group.should eql(group)

    end

  end

  describe "adding a member to a group" do

    it "should add a member to a group" do
      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      new_user = SecureRandom.uuid
      @user_service.create_user(:id => new_user)
      new_group_json = @group_service.add_user_to_group(group[:id], new_user)
      new_group = Yajl::Parser.parse(new_group_json, :symbolize_keys => true)

      (new_group[:members].include? (new_user)).should be_true
    end

  end

  describe "removing a member from a group" do

    it "should work with the remove_user_from_group api" do
      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      new_group_json = @group_service.remove_user_from_group(group[:id], @user4)
      new_group = Yajl::Parser.parse(new_group_json, :symbolize_keys => true)

      (new_group[:members].include? (@user4)).should be_false
    end

    it "should not be possible to remove a member that does not exist in the group" do
      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      new_user = SecureRandom.uuid
      lambda {
        new_group_json = @group_service.remove_user_from_group(group[:id], new_user)
      }.should raise_error
    end

  end


  describe "updating a group" do 

    before(:each) do
      group_json = @group_service.create_group(:id => "g-#{@group1}",
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

    end
    
    it "should be able to replace all the properties of an existing group" do 
      new_group_json = @group_service.update_group(:id => "g-#{@group1}",
                                                   :additional_info => "Updated Developer group",
                                                   :members => [@user1])

      updated_group = Yajl::Parser.parse(new_group_json, :symbolize_keys => true)
      updated_group[:additional_info].should eql("Updated Developer group")
      updated_group[:members].should eql([@user1])
      updated_group[:id].should eql("g-#{@group1}")
   
    end

    it "should be able to replace the group with an empty one" do 
      new_group_json = @group_service.update_group(:id => "g-#{@group1}")

      updated_group = Yajl::Parser.parse(new_group_json, :symbolize_keys => true)
      updated_group[:additional_info].should be_nil
      updated_group[:members].should be_nil
      updated_group[:id].should eql("g-#{@group1}")

    end

    it "should be able to replace the group with nil members or other fields" do 
      new_group_json = @group_service.update_group(:id => "g-#{@group1}",
                                                   :additional_info => nil,
                                                   :members => nil)


      updated_group = Yajl::Parser.parse(new_group_json, :symbolize_keys => true)
      updated_group[:additional_info].should be_nil
      updated_group[:members].should be_nil
      updated_group[:id].should eql("g-#{@group1}")

    end

    it "should be able to replace the group with nil members or other fields" do 
      new_group_json = @group_service.update_group(:id => "g-#{@group1}",
                                                   :additional_info => "",
                                                   :members => [])

      updated_group = Yajl::Parser.parse(new_group_json, :symbolize_keys => true)
      updated_group[:additional_info].should eql("")
      updated_group[:members].should be_nil
      updated_group[:id].should eql("g-#{@group1}")

    end

    it "should be able to replace the group with nil members or other fields" do 
      new_group_json = @group_service.update_group(:id => "g-#{@group1}",
                                                   :additional_info => "",
                                                   :members => [nil])

      updated_group = Yajl::Parser.parse(new_group_json, :symbolize_keys => true)
      updated_group[:additional_info].should eql("")
      updated_group[:members].should be_nil
      updated_group[:id].should eql("g-#{@group1}")

    end
    
    it "should raise an error for a group that does not exist" do 
      lambda {
        new_group = SecureRandom.uuid
        new_group_json = @group_service.update_group(:id => new_group,
                                                     :additional_info => "Updated Developer group",
                                                     :members => [@user1])
      }.should raise_error

    end

  end

end
