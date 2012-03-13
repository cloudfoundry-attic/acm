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

require 'acm/services/permission_set_service'
require 'json'

describe ACM::Services::PermissionSetService do

  before(:each) do
    @permission_set_service = ACM::Services::PermissionSetService.new()

    @logger = ACM::Config.logger
  end


  describe "creating a permission set" do

    it "should create a permission set with a fixed set of permissions" do
      ps_json = @permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace]
      )

      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)

      ps[:name].should eql("app_space")
      ps[:permissions].sort().should eql(["read_appspace", "update_appspace", "delete_appspace"].sort())
      ps[:meta][:created].should_not be_nil
      ps[:meta][:updated].should_not be_nil
    end

    it "should create an empty permission set" do
      ps_json = @permission_set_service.create_permission_set(:name => "app_space")

      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)

      ps[:name].should eql("app_space")
      ps[:permissions].should eql([])
      ps[:meta][:created].should_not be_nil
      ps[:meta][:updated].should_not be_nil
    end

    it "should error out if no name is provided" do
      lambda {
        ps_json = @permission_set_service.create_permission_set()
      }.should raise_error(ACM::ACMError)
    end

    it "should reject duplicate permission names even in different permission sets" do
      lambda {
        @permission_set_service.create_permission_set(:name => :app_space, :permissions => [:read, :write])
        @permission_set_service.create_permission_set(:name => :collab_space, :permissions => [:delete, :write])
      }.should raise_error(ACM::ACMError)
    end

    it "should create a permission set with additional info" do
      ps_json = @permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace],
                                                              :additional_info => "this is the permission set for the app space"
      )

      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)

      ps[:name].should eql("app_space")
      ps[:permissions].sort().should eql(["read_appspace", "update_appspace", "delete_appspace"].sort())
      ps[:additional_info].should eql("this is the permission set for the app space")
      ps[:meta][:created].should_not be_nil
      ps[:meta][:updated].should_not be_nil
    end

  end

  describe "updating a permission set" do
    before(:each) do
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @logger = ACM::Config.logger

      @ps_json = @permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace],
                                                              :additional_info => "this is the permission set for the app space"
      )

      @ps = Yajl::Parser.parse(@ps_json, :symbolize_keys => true)

      @object_service = ACM::Services::ObjectService.new()
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

    it "should update a permission set that is not referenced by any objects and return the updated json" do
      updated_ps = Yajl::Parser.parse(@permission_set_service.update_permission_set(:name => :app_space), :symbolize_keys => true)
      
      updated_ps[:name].should eql(@ps[:name])
      updated_ps[:additional_info].should be_nil
      updated_ps[:permissions].size().should eql(0)
       
      updated_ps = Yajl::Parser.parse(@permission_set_service.update_permission_set(:name => :app_space,
                                                                 :additional_info => "yadayadayada",
                                                                 :permissions => [:read_appspace, :update_appspace]), :symbolize_keys => true)
                                                                    
      updated_ps[:name].should eql(@ps[:name])
      updated_ps[:additional_info].should eql("yadayadayada")
      updated_ps[:permissions].sort().should eql(["read_appspace", "update_appspace"].sort())
      
      updated_ps = Yajl::Parser.parse(@permission_set_service.update_permission_set(:name => :app_space,
                                                                 :additional_info => "yadayadayada",
                                                                 :permissions => [:read_appspace, :update_appspace, :new_permission]), :symbolize_keys => true)
                                                                    
      updated_ps[:name].should eql(@ps[:name])
      updated_ps[:additional_info].should eql("yadayadayada")
      updated_ps[:permissions].sort().should eql(["read_appspace", "update_appspace", "new_permission"].sort())

      updated_ps = Yajl::Parser.parse(@permission_set_service.update_permission_set(:name => :app_space,
                                                                 :additional_info => "yadayadayada",
                                                                 :permissions => [:new_permission]), :symbolize_keys => true)
                                                                    
      updated_ps[:name].should eql(@ps[:name])
      updated_ps[:additional_info].should eql("yadayadayada")
      updated_ps[:permissions].sort().should eql(["new_permission"].sort())
    end

    it "should fail to update a permission set removing permissions that are tied in an object" do
      new_object = @object_service.create_object(:name => "www_staging",
                                                :additional_info => {:description => :staging_app_space}.to_json(),
                                                :permission_sets => [:app_space],
                                                :acl => {
                                                    :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
                                                    :update_appspace => ["u-#{@user1}", "u-#{@user3}", "u-#{@user4}"]
                                                })

      lambda {
        updated_ps = Yajl::Parser.parse(@permission_set_service.update_permission_set(:name => :app_space), :symbolize_keys => true) 
      }.should raise_error

      lambda {
        updated_ps = Yajl::Parser.parse(@permission_set_service.update_permission_set(:name => :app_space,
                                                                                      :permissions => [:new_permission],
                                                                                     ), :symbolize_keys => true) 
      }.should raise_error
      
      lambda {
       updated_ps = Yajl::Parser.parse(@permission_set_service.update_permission_set(:name => :app_space,
                                                                                      :permissions => [:read_appspace, :new_permission],
                                                                                     ), :symbolize_keys => true) 
      }.should raise_error
     
    end

    it "should be able to assign existing permissions to new permission sets" do
      object = Yajl::Parser.parse(@object_service.create_object(:name => "www_staging",
                                                :additional_info => {:description => :staging_app_space}.to_json(),
                                                :permission_sets => [:app_space],
                                                :acl => {
                                                    :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
                                                    :update_appspace => ["u-#{@user1}", "u-#{@user3}", "u-#{@user4}"]
                                                }), :symbolize_keys => true)

      new_ps = Yajl::Parser.parse(@permission_set_service.create_permission_set(:name => :collab_space), :symbolize_keys => true)

      updated_object = object
      updated_object[:permission_sets].unshift(new_ps[:name])
      final_object = Yajl::Parser.parse(@object_service.update_object(updated_object), :symbolize_keys => true)

      updated_ps = @permission_set_service.update_permission_set(:name => new_ps[:name],
                                                                 :permissions => [:update_appspace],
                                                                 :additional_info => "this is the permission set for the app space")

      final_object[:permission_sets].should eql([@ps[:name], new_ps[:name]].sort())
      final_object[:acl].each { |permission, users|
        object[:acl][permission].sort().should eql(final_object[:acl][permission].sort())
      }

    end

    it "should be possible to rename a permission set" do
      object = Yajl::Parser.parse(@object_service.create_object(:name => "www_staging",
                                                :additional_info => {:description => :staging_app_space}.to_json(),
                                                :permission_sets => [:app_space],
                                                :acl => {
                                                    :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
                                                    :update_appspace => ["u-#{@user1}", "u-#{@user3}", "u-#{@user4}"]
                                                }), :symbolize_keys => true)

      new_ps = Yajl::Parser.parse(@permission_set_service.create_permission_set(:name => :collab_space), :symbolize_keys => true)

      updated_object = object
      updated_object[:permission_sets].unshift(new_ps[:name])
      @object_service.update_object(updated_object)

      updated_ps = @permission_set_service.update_permission_set(:name => new_ps[:name],
                                                                 :permissions => @ps[:permissions],
                                                                 :additional_info => @ps[:additional_info])

      updated_object[:permission_sets] = [new_ps[:name]]
      final_object = Yajl::Parser.parse(@object_service.update_object(updated_object), :symbolize_keys => true)

      final_object[:permission_sets].should eql([new_ps[:name]])
      final_object[:acl].each { |permission, users|
        object[:acl][permission].sort().should eql(final_object[:acl][permission].sort())
      }


    end

  end

  describe "reading a permission set" do

    before(:each) do
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @logger = ACM::Config.logger
    end

    it "should return the correct permission set for a valid name" do
      ps_json = @permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace],
                                                              :additional_info => "this is the permission set for the app space"
      )

      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)

      read_ps_json = @permission_set_service.read_permission_set(:app_space)
      read_ps = Yajl::Parser.parse(read_ps_json, :symbolize_keys => true)

      read_ps.should eql(ps)
    end

    it "should return an error if it cannot find a permission set" do
      ps_json = @permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace],
                                                              :additional_info => "this is the permission set for the app space"
      )

      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)

      lambda {
        @permission_set_service.read_permission_set(:unknown_permission_set)
      }.should raise_error(ACM::ACMError)

    end

  end

  describe "deleting a permission set" do
    before(:each) do
      @permission_set_service = ACM::Services::PermissionSetService.new()

      @logger = ACM::Config.logger

      @ps1 = Yajl::Parser.parse(@permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace],
                                                              :additional_info => "this is the permission set for the app space"))

      @ps2 = Yajl::Parser.parse(@permission_set_service.create_permission_set(:name => :collab_space))


      @object_service = ACM::Services::ObjectService.new()
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

    it "should delete a permission set that is not referenced by any objects" do
      updated_ps = @permission_set_service.delete_permission_set("app_space")
      
      updated_ps.should be_nil

      updated_ps = @permission_set_service.delete_permission_set("collab_space")
      
      updated_ps.should be_nil
       
    end

    it "should fail to delete a permission set with existing permissions that are tied to an object" do
      new_object = @object_service.create_object(:name => "www_staging",
                                                :additional_info => {:description => :staging_app_space}.to_json(),
                                                :permission_sets => [:app_space],
                                                :acl => {
                                                    :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
                                                    :update_appspace => ["u-#{@user1}", "u-#{@user3}", "u-#{@user4}"]
                                                })

      lambda {
        @permission_set_service.delete_permission_set("app_space")
      }.should raise_error

    end

    # Just to make sure everything is really cleaned up
    it "should be possible to recreate a deleted permission set" do
      updated_ps = @permission_set_service.delete_permission_set("app_space")
      
      updated_ps.should be_nil

      ps_json = Yajl::Parser.parse(@permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace],
                                                              :additional_info => "this is the permission set for the app space"))

      ps_json.should eql(@ps1)

    end


  end

end
