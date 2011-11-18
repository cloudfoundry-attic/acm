require File.expand_path("../../spec_helper", __FILE__)

require "rack/test"
require "json"

describe ACM::Controller::RackController do
  include Rack::Test::Methods

  def app
    @app ||= ACM::Controller::RackController.new
  end

  describe "object management" do

    before(:each) do
      #Fix the schema
      ps1 = ACM::Models::PermissionSets.new(:name => :app_space.to_s)
      ps1.save
      ps2 = ACM::Models::PermissionSets.new(:name => :director.to_s)
      ps2.save
      ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :read_appspace.to_s).save
      ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :write_appspace.to_s).save
      ACM::Models::Permissions.new(:permission_set_id => ps1.id, :name => :delete_appspace.to_s).save

      @logger = ACM::Config.logger
    end

    def payload(params)
      { "CONTENT_TYPE" => "application/json", :input => Yajl::Encoder.encode(params)}
    end

    it "will create a new object and return it's representation" do
      basic_authorize "admin", "password"

      object_data = {
        :object_type => :app_space,
        :id => "54947df8-0e9e-4471-a2f9-9af509fb5889",
        :additionalInfo => {:component => :cloud_controller},
        :permissionSet => [
          :read_app,
          :update_app,
          :read_app_logs,
          :read_service,
          :write_service
         ],
         :meta => {
            :updated => 1273740902,
            :created => 1273726800,
            :schema => ":urn:acm:schemas:1.0"
         }
      }.to_json()

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data }
      @logger.debug("last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

    end
  end

end
