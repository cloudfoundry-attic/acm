require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/permission_set_service'
require 'json'

describe ACM::Services::PermissionSetService do

  before(:each) do
    @permission_set_service = ACM::Services::PermissionSetService.new()

    @logger = ACM::Config.logger
  end


  describe "creating an empty permission set" do

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

    it "should create a permission set with additional info" do
      ps_json = @permission_set_service.create_permission_set(:name => :app_space,
                                                              :permissions => [:read_appspace, :update_appspace, :delete_appspace],
                                                              :additional_info => "this is the permission set for the app space"
      )

      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)

      ps[:name].should eql("app_space")
      ps[:permissions].sort().should eql(["read_appspace", "update_appspace", "delete_appspace"].sort())
      ps[:additionalInfo].should eql("this is the permission set for the app space")
      ps[:meta][:created].should_not be_nil
      ps[:meta][:updated].should_not be_nil
    end

  end

end
