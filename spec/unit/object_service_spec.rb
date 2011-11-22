require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/object_service'
require 'acm/services/user_service'
require 'acm/models/permissions'
require 'acm/models/permission_sets'
require 'json'

describe ACM::Services::ObjectService do

  before(:each) do
    #Fix the schema
    ps1 = ACM::Models::PermissionSets.new(:name => :app_space.to_s)
    ps1.save
    ps2 = ACM::Models::PermissionSets.new(:name => :director.to_s)
    ps2.save
    ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :read_appspace.to_s).save
    ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :write_appspace.to_s).save
    ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :delete_appspace.to_s).save

    @object_service = ACM::Services::ObjectService.new()
    @user_service = ACM::Services::UserService.new()
    @logger = ACM::Config.logger
  end

  describe "creating an object" do

    it "should create an object with a valid id" do

      o_json = @object_service.create_object(:name => "www_staging")

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:name].should eql("www_staging")
      object[:id].should_not be_nil
      object[:type].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "should create an object with a valid id even without a name" do

      o_json = @object_service.create_object()

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:type].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "should create an object with a valid id with additional info" do

      o_json = @object_service.create_object(:additional_info => {:description => :staging_app_space}.to_json())

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:type].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil
      object[:additionalInfo].should eql({:description => :staging_app_space}.to_json())

    end

    it "should create an object and associate it with a set of permission types" do

      o_json = @object_service.create_object(:permission_sets => [:app_space])

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:type].should_not be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "should create an object with multiple types"

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

    end

    it "should correctly update the object with a new acl" do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user_id)
      @logger.debug("Returned object is #{new_object_json.inspect}")
      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      (new_object[:acl][:read_appspace].include? @user_id).should be_true
    end

    it "should correctly update the object with multiple acls " do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user_id)
      @logger.debug("Returned object is #{new_object_json.inspect}")

      user2_json = @user_service = ACM::Services::UserService.new().create_user()
      user2 = Yajl::Parser.parse(user2_json, :symbolize_keys => true)
      new_object2_json = @object_service.add_permission(@obj_id, :read_appspace, user2[:id])
      @logger.debug("Returned object is #{new_object2_json.inspect}")

      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)
      new_object2 = Yajl::Parser.parse(new_object2_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      new_object2[:id].should eql(@obj_id)

      (new_object[:acl][:read_appspace].include? @user_id).should be_true
      (new_object2[:acl][:read_appspace].include? user2[:id]).should be_true
    end

    it "should correctly update the object acls with multiple permissions" do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user_id)
      @logger.debug("Returned object is #{new_object_json.inspect}")

      user2_json = @user_service = ACM::Services::UserService.new().create_user()
      user2 = Yajl::Parser.parse(user2_json, :symbolize_keys => true)
      new_object2_json = @object_service.add_permission(@obj_id, :write_appspace, user2[:id])
      @logger.debug("Returned object is #{new_object2_json.inspect}")

      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)
      new_object2 = Yajl::Parser.parse(new_object2_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      new_object2[:id].should eql(@obj_id)

      (new_object[:acl][:read_appspace].include? @user_id).should be_true
      (new_object2[:acl][:write_appspace].include? user2[:id]).should be_true
    end

    it "should correctly update the object acls that have multiple permissions with multiple permissions" do
      new_object_json = @object_service.add_permission(@obj_id, :read_appspace, @user_id)
      @logger.debug("Returned object is #{new_object_json.inspect}")

      user2_json = @user_service = ACM::Services::UserService.new().create_user()
      user2 = Yajl::Parser.parse(user2_json, :symbolize_keys => true)
      new_object2_json = @object_service.add_permission(@obj_id, :read_appspace, user2[:id])
      @logger.debug("Returned object is #{new_object2_json.inspect}")

      user3_json = @user_service = ACM::Services::UserService.new().create_user()
      user3 = Yajl::Parser.parse(user3_json, :symbolize_keys => true)
      new_object3_json = @object_service.add_permission(@obj_id, :write_appspace, user3[:id])
      @logger.debug("Returned object is #{new_object3_json.inspect}")

      user4_json = @user_service = ACM::Services::UserService.new().create_user()
      user4 = Yajl::Parser.parse(user4_json, :symbolize_keys => true)
      new_object4_json = @object_service.add_permission(@obj_id, :write_appspace, user4[:id])
      @logger.debug("Returned object is #{new_object4_json.inspect}")

      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)
      new_object2 = Yajl::Parser.parse(new_object2_json, :symbolize_keys => true)
      new_object3 = Yajl::Parser.parse(new_object3_json, :symbolize_keys => true)
      new_object4 = Yajl::Parser.parse(new_object4_json, :symbolize_keys => true)

      new_object[:id].should eql(@obj_id)
      new_object2[:id].should eql(@obj_id)
      new_object3[:id].should eql(@obj_id)
      new_object4[:id].should eql(@obj_id)

      (new_object[:acl][:read_appspace].include? @user_id).should be_true
      (new_object2[:acl][:read_appspace].include? user2[:id]).should be_true
      (new_object3[:acl][:write_appspace].include? user3[:id]).should be_true
      (new_object4[:acl][:write_appspace].include? user4[:id]).should be_true
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

end