require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/object_service'
require 'acm/services/user_service'
require 'acm/models/permissions'
require 'acm/models/permission_sets'
require 'json'

describe ACM::Services::ObjectService do

  before(:each) do

    @object_service = ACM::Services::ObjectService.new()
    @user_service = ACM::Services::UserService.new()
    @group_service = ACM::Services::GroupService.new()
    @permission_set_service = ACM::Services::PermissionSetService.new()

    @permission_set_service.create_permission_set(:name => :app_space,
                                                  :permissions => [:read_appspace, :write_appspace, :delete_appspace],
                                                  :additional_info => "this is the permission set for the app space")

    @permission_set_service.create_permission_set(:name => :director)

    @logger = ACM::Config.logger
  end

  describe "creating an object" do

    it "should create an object with a valid id" do

      o_json = @object_service.create_object(:name => "www_staging")

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:name].should eql("www_staging")
      object[:id].should_not be_nil
      object[:permission_sets].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "should create an object with a valid id even without a name" do

      o_json = @object_service.create_object()

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:permission_sets].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "should create an object with a valid id with additional info" do

      o_json = @object_service.create_object(:additional_info => {:description => :staging_app_space}.to_json())

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:permission_sets].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil
      object[:additionalInfo].should eql({:description => :staging_app_space}.to_json())

    end

    it "should create an object and associate it with a set of permission types" do

      o_json = @object_service.create_object(:permission_sets => [:app_space])

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:permission_sets].should_not be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "should create an object with multiple types"

    it "should not create an object with a permission that's not supported by its permission_set'" do
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid

      lambda {
        o_json = @object_service.create_object(:name => "www_staging",
                                            :additional_info => {:description => :staging_app_space}.to_json(),
                                            :permission_sets => [:app_space],
                                            :acl => {
                                                :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
                                                :update_appspace => ["u-#{@user1}", "u-#{@user3}", "u-#{@user4}"]
                                            })
      }.should raise_error(ACM::InvalidRequest)


    end


    it "should create an object with multiple users" do
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid

      o_json = @object_service.create_object(:name => "www_staging",
                                            :additional_info => {:description => :staging_app_space}.to_json(),
                                            :permission_sets => [:app_space],
                                            :acl => {
                                                :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"],
                                                :write_appspace => ["u-#{@user1}", "u-#{@user3}", "u-#{@user4}"]
                                            })
      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:name].should eql("www_staging")

      object[:acl][:read_appspace].sort().should eql(["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}"].sort())
      object[:acl][:write_appspace].sort().should eql(["u-#{@user1}", "u-#{@user3}", "u-#{@user4}"].sort())

    end

    it "should create an object with multiple groups" do
      @group1 = SecureRandom.uuid
      @group_service.create_group(:id => @group1)
      @group2 = SecureRandom.uuid
      @group_service.create_group(:id => @group2)
      @group3 = SecureRandom.uuid
      @group_service.create_group(:id => @group3)
      @group4 = SecureRandom.uuid
      @group_service.create_group(:id => @group4)

      o_json = @object_service.create_object(:name => "www_staging",
                                            :additional_info => {:description => :staging_app_space}.to_json(),
                                            :permission_sets => [:app_space],
                                            :acl => {
                                                :read_appspace => ["g-#{@group1}", "g-#{@group2}", "g-#{@group3}", "g-#{@group4}"],
                                                :write_appspace => ["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"]
                                            })
      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:name].should eql("www_staging")

      object[:acl][:read_appspace].sort().should eql(["g-#{@group1}", "g-#{@group2}", "g-#{@group3}", "g-#{@group4}"].sort())
      object[:acl][:write_appspace].sort().should eql(["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"].sort())

    end

    it "should not create an object with groups that do not exist" do
      @group1 = SecureRandom.uuid
      @group_service.create_group(:id => @group1)
      @group2 = SecureRandom.uuid
      @group_service.create_group(:id => @group2)
      @group3 = SecureRandom.uuid
      @group_service.create_group(:id => @group3)
      @group4 = SecureRandom.uuid

      lambda {
        o_json = @object_service.create_object(:name => "www_staging",
                                              :additional_info => {:description => :staging_app_space}.to_json(),
                                              :permission_sets => [:app_space],
                                              :acl => {
                                                  :read_appspace => ["g-#{@group1}", "g-#{@group2}", "g-#{@group3}", "g-#{@group4}"],
                                                  :write_appspace => ["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"]
                                              })
      }.should raise_error(ACM::InvalidRequest)

    end

    it "should create an object with multiple users and groups" do
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid
      @user5 = SecureRandom.uuid
      @user6 = SecureRandom.uuid

      @group1 = SecureRandom.uuid
      @group_service.create_group(:id => @group1, :members => [@user1])
      @group2 = SecureRandom.uuid
      @group_service.create_group(:id => @group2)
      @group3 = SecureRandom.uuid
      @group_service.create_group(:id => @group3)
      @group4 = SecureRandom.uuid
      @group_service.create_group(:id => @group4, :members => [@user4, @user5, @user6])


      o_json = @object_service.create_object(:name => "www_staging",
                                            :additional_info => {:description => :staging_app_space}.to_json(),
                                            :permission_sets => [:app_space],
                                            :acl => {
                                                :read_appspace => ["g-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"],
                                                :write_appspace => ["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"],
                                                :delete_appspace => ["u-#{@user2}", "u-#{@user5}", "g-#{@group3}"]
                                            })
      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:name].should eql("www_staging")

      object[:acl][:read_appspace].sort().should eql(["g-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"].sort())
      object[:acl][:write_appspace].sort().should eql(["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"].sort())
      object[:acl][:delete_appspace].sort().should eql(["u-#{@user2}", "u-#{@user5}", "g-#{@group3}"].sort())

    end

    it "should error out if users and groups are mixed up" do
      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid
      @user5 = SecureRandom.uuid
      @user6 = SecureRandom.uuid

      @group1 = SecureRandom.uuid
      @group_service.create_group(:id => @group1, :members => [@user1])
      @group2 = SecureRandom.uuid
      @group_service.create_group(:id => @group2)
      @group3 = SecureRandom.uuid
      @group_service.create_group(:id => @group3)
      @group4 = SecureRandom.uuid
      @group_service.create_group(:id => @group4, :members => [@user4, @user5, @user6])

      lambda {
        o_json = @object_service.create_object(:name => "www_staging",
                                              :additional_info => {:description => :staging_app_space}.to_json(),
                                              :permission_sets => [:app_space],
                                              :acl => {
                                                  :read_appspace => ["u-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"],
                                                  :write_appspace => ["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"],
                                                  :delete_appspace => ["u-#{@user2}", "u-#{@user5}", "g-#{@group3}"]
                                              })
      }.should raise_error(ACM::InvalidRequest)

      lambda {
        o_json = @object_service.create_object(:name => "www_staging",
                                              :additional_info => {:description => :staging_app_space}.to_json(),
                                              :permission_sets => [:app_space],
                                              :acl => {
                                                  :read_appspace => ["g-#{@group1}", "g-#{@group2}", "g-#{@group4}", "u-#{@user1}", "u-#{@user6}"],
                                                  :write_appspace => ["g-#{@group1}", "g-#{@group3}", "g-#{@group4}"],
                                                  :delete_appspace => ["u-#{@user2}", "g-#{@user5}", "g-#{@group3}"]
                                              })
      }.should raise_error(ACM::InvalidRequest)

    end


  end

  describe "adding permissions to an object" do

    before(:each) do
      o_json = @object_service.create_object(:name => "www_staging",
                                            :additional_info => {:description => :staging_app_space}.to_json(),
                                            :permission_sets => [:app_space])

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      @obj_id = object[:id]
      @obj_id.should_not be_nil

      user_json = ACM::Services::UserService.new().create_user()
      user = Yajl::Parser.parse(user_json, :symbolize_keys => true)
      @user_id = user[:id]
      @user_id.should_not be_nil

      @user1 = SecureRandom.uuid
      @user_service.create_user(:id => @user1)
      @user2 = SecureRandom.uuid
      @user_service.create_user(:id => @user2)
      @user3 = SecureRandom.uuid
      @user_service.create_user(:id => @user3)
      @user4 = SecureRandom.uuid
      @user_service.create_user(:id => @user4)

    end

    it "should correctly update the object with a new acl" do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user_id)
      @logger.debug("Returned object is #{new_object_json.inspect}")
      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      (new_object[:acl][:read_appspace].include? "u-#{@user_id}").should be_true
    end

    it "should correctly update the object with multiple acls " do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user1)
      @logger.debug("Returned object is #{new_object_json.inspect}")

      new_object2_json = @object_service.add_permission(@obj_id, :read_appspace, @user2)
      @logger.debug("Returned object is #{new_object2_json.inspect}")

      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)
      new_object2 = Yajl::Parser.parse(new_object2_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      new_object2[:id].should eql(@obj_id)

      (new_object[:acl][:read_appspace].include? "u-#{@user1}").should be_true
      (new_object2[:acl][:read_appspace].include? "u-#{@user2}").should be_true
    end

    it "should correctly update the object acls with multiple permissions" do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user1)
      @logger.debug("Returned object is #{new_object_json.inspect}")

      new_object2_json = @object_service.add_permission(@obj_id, :write_appspace, @user2)
      @logger.debug("Returned object is #{new_object2_json.inspect}")

      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)
      new_object2 = Yajl::Parser.parse(new_object2_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      new_object2[:id].should eql(@obj_id)

      (new_object[:acl][:read_appspace].include? "u-#{@user1}").should be_true
      (new_object2[:acl][:write_appspace].include? "u-#{@user2}").should be_true
    end

    it "should correctly update the object acls that have multiple permissions with multiple permissions" do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user1)
      @logger.debug("Returned object is #{new_object_json.inspect}")

      new_object2_json = @object_service.add_permission(@obj_id, :read_appspace, @user2)
      @logger.debug("Returned object is #{new_object2_json.inspect}")

      new_object3_json = @object_service.add_permission(@obj_id, :write_appspace, @user3)
      @logger.debug("Returned object is #{new_object3_json.inspect}")

      new_object4_json = @object_service.add_permission(@obj_id, :write_appspace, @user4)
      @logger.debug("Returned object is #{new_object4_json.inspect}")

      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)
      new_object2 = Yajl::Parser.parse(new_object2_json, :symbolize_keys => true)
      new_object3 = Yajl::Parser.parse(new_object3_json, :symbolize_keys => true)
      new_object4 = Yajl::Parser.parse(new_object4_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      new_object2[:id].should eql(@obj_id)
      new_object3[:id].should eql(@obj_id)
      new_object4[:id].should eql(@obj_id)

      (new_object[:acl][:read_appspace].include? "u-#{@user1}").should be_true
      (new_object2[:acl][:read_appspace].include? "u-#{@user2}").should be_true
      (new_object3[:acl][:write_appspace].include? "u-#{@user3}").should be_true
      (new_object4[:acl][:write_appspace].include? "u-#{@user4}").should be_true
    end

  end

  describe "getting an object" do

    it "should correctly fetch an object requested" do

      o_json = @object_service.create_object(:name => "www_staging")

      created_object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      read_object_json = @object_service.read_object(created_object[:id])

      read_object = Yajl::Parser.parse(read_object_json, :symbolize_keys => true)

      read_object.should eql(created_object)
    end

    it "should raise an exception when the object id does not exist" do

      lambda {
        read_object_json = @object_service.read_object("12345")
      }.should raise_error(ACM::ACMError)

    end

  end

  describe "deleting an object" do

    it "should delete the object requested" do

      o_json = @object_service.create_object(:name => "www_staging")

      created_object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      @object_service.delete_object(created_object[:id])

      lambda {
        read_object_json = @object_service.read_object(created_object[:id])
      }.should raise_error(ACM::ACMError)
    end

    it "should raise an exception when the object id does not exist" do

      lambda {
        read_object_json = @object_service.delete_object("12345")
      }.should raise_error(ACM::ACMError)

    end

  end

  describe "getting users for an object" do

    before (:each) do
      @logger = ACM::Config.logger

      @user1 = SecureRandom.uuid
      @user2 = SecureRandom.uuid
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid
      @user5 = SecureRandom.uuid
      @user6 = SecureRandom.uuid
      @user7 = SecureRandom.uuid

      @group1 = SecureRandom.uuid
      @group2 = SecureRandom.uuid

      group_json = @group_service.create_group(:id => @group1,
                                              :additional_info => "Developer group",
                                              :members => [@user3, @user4])

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group_json = @group_service.create_group(:id => @group2,
                                              :additional_info => "Another developer group",
                                              :members => [@user5, @user6, @user7])

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      o_json = @object_service.create_object(:name => "www_staging",
                                      :additional_info => {:description => :staging_app_space}.to_json(),
                                      :permission_sets => [:app_space],
                                      :acl => {
                                        :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}", "g-#{@group2}"],
                                        :write_appspace => ["u-#{@user2}", "g-#{@group1}"],
                                        :delete_appspace => ["u-#{@user4}"]
                                      })
      @object = Yajl::Parser.parse(o_json, :symbolize_keys => true)
    end

    it "should correctly fetch the users for an object along with it's permissions" do
      object_id = @object[:id]

      user_permission_map = @object_service.get_users_for_object(object_id)
      @logger.debug("user_permission_entries #{user_permission_map.inspect}")

      user_permission_map.size().should eql(7)

      user_permission_map[@user1].sort().should eql([:read_appspace.to_s].sort())
      user_permission_map[@user2].sort().should eql([:read_appspace.to_s, :write_appspace.to_s].sort())
      user_permission_map[@user3].sort().should eql([:read_appspace.to_s, :write_appspace.to_s].sort())
      user_permission_map[@user4].sort().should eql([:read_appspace.to_s, :write_appspace.to_s, :delete_appspace.to_s].sort())
      user_permission_map[@user5].sort().should eql([:read_appspace.to_s].sort())
      user_permission_map[@user6].sort().should eql([:read_appspace.to_s].sort())
      user_permission_map[@user7].sort().should eql([:read_appspace.to_s].sort())
    end

  end

  describe "removing users from an object's ace" do

    before (:each) do
      @logger = ACM::Config.logger

      @user1 = SecureRandom.uuid
      @user2 = SecureRandom.uuid
      @user3 = SecureRandom.uuid
      @user4 = SecureRandom.uuid
      @user5 = SecureRandom.uuid
      @user6 = SecureRandom.uuid
      @user7 = SecureRandom.uuid

      @group1 = SecureRandom.uuid
      @group2 = SecureRandom.uuid

      group_json = @group_service.create_group(:id => @group1,
                                              :additional_info => "Developer group",
                                              :members => [@user3, @user4])

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group_json = @group_service.create_group(:id => @group2,
                                              :additional_info => "Another developer group",
                                              :members => [@user5, @user6, @user7])

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      o_json = @object_service.create_object(:name => "www_staging",
                                      :additional_info => {:description => :staging_app_space}.to_json(),
                                      :permission_sets => [:app_space],
                                      :acl => {
                                        :read_appspace => ["u-#{@user1}", "u-#{@user2}", "u-#{@user3}", "u-#{@user4}", "g-#{@group2}"],
                                        :write_appspace => ["u-#{@user2}", "g-#{@group1}"],
                                        :delete_appspace => ["u-#{@user4}"]
                                      })
      @object = Yajl::Parser.parse(o_json, :symbolize_keys => true)
    end

    it "should correctly remove a user from an object's ace given a single permission" do
      object_id = @object[:id]

      o_json = @object_service.remove_subjects_from_ace(object_id, :read_appspace, @user1)

      o_json.should_not be_nil
      @updated_object_json = Yajl::Parser.parse(o_json, :symbolize_keys => true)
      (@updated_object_json[:acl][:read_appspace].include? "u-#{@user1}").should_not be_true
        
      o_json = @object_service.remove_subjects_from_ace(object_id, :read_appspace, @user4)

      o_json.should_not be_nil
      @updated_object_json = Yajl::Parser.parse(o_json, :symbolize_keys => true)
      (@updated_object_json[:acl][:read_appspace].include? "u-#{@user4}").should_not be_true


    end
    
    it "should correctly remove a set of permissions from an object's ace given a single permission" do
      object_id = @object[:id]

      o_json = @object_service.remove_subjects_from_ace(object_id, [:read_appspace, :write_appspace], @user2)

      o_json.should_not be_nil
      @updated_object_json = Yajl::Parser.parse(o_json, :symbolize_keys => true)
      (@updated_object_json[:acl][:read_appspace].include? "u-#{@user2}").should_not be_true
      (@updated_object_json[:acl][:write_appspace].include? "u-#{@user2}").should_not be_true

    end
  end

end

