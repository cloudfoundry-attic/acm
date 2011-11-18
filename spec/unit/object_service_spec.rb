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

    it "will create an object with a valid id" do

      o_json = @object_service.create_object(:name => "www_staging")

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:name].should eql("www_staging")
      object[:id].should_not be_nil
      object[:type].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "will create an object with a valid id even without a name" do

      o_json = @object_service.create_object()

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:type].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

    it "will create an object with a valid id with additional info" do

      o_json = @object_service.create_object(:additional_info => {:description => :staging_app_space}.to_json())

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:type].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil
      object[:additional_info].should eql({:description => :staging_app_space}.to_json())

    end

    it "will create an object and associate it with a set of permission types" do

      o_json = @object_service.create_object(:permission_sets => [:app_space])

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:type].should_not be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil

    end

  end

  describe "adding permissions to an object" do

    it "should update the object entity with a new acl" do
      o_json = @object_service.create_object(:name => "www_staging",
                                            :additional_info => {:description => :staging_app_space}.to_json(),
                                            :permission_sets => [:app_space])

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      obj_id = object[:id]
      obj_id.should_not be_nil

      user_json = @user_service = ACM::Services::UserService.new().create_user()

      user = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      user_id = user[:id]
      user_id.should_not be_nil

      new_object_json = @object_service.add_permission(obj_id, :read_appspace, user_id)

      @logger.debug("Returned object is #{new_object_json.inspect}")

      new_object = Yajl::Parser.parse(new_object_json, :symbolize_keys => true)

      new_object[:id].should eql(obj_id)

      (new_object[:acls][:read_appspace].include? user_id).should be_true
    end

  end

end