require File.expand_path("../../spec_helper", __FILE__)

require "rack/test"
require "json"

describe ACM::Controller::RackController do
  include Rack::Test::Methods

  def app
    @app ||= ACM::Controller::RackController.new
  end

  describe "object creation" do

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

    it "should create a new object and return it's representation" do
      basic_authorize "admin", "password"

      object_data = {
        :name => "www_staging",
        :type => ["app_space"],
        :id => "54947df8-0e9e-4471-a2f9-9af509fb5889",
        :additionalInfo => "{component => cloud_controller}",
        :meta => {
          :updated => 1273740902,
          :created => 1273726800,
          :schema => "urn:acm:schemas:1.0"
        }
      }

      post "/objects", {}, { "CONTENT_TYPE" => "application/json", :input => object_data.to_json() }
      @logger.debug("post /objects last response #{last_response.inspect}")
      last_response.status.should eql(200)
      last_response.original_headers["Content-Type"].should eql("application/json;charset=utf-8")
      last_response.original_headers["Content-Length"].should_not eql("0")

      body = Yajl::Parser.parse(last_response.body, :symbolize_keys => true)

      body[:name].to_s.should eql(object_data[:name].to_s)
      body[:type].should eql(object_data[:type])
      body[:additionalInfo].should eql(object_data[:additionalInfo])
      body[:id].should_not be_nil
      body[:id].should_not eql(object_data[:id])
      body[:meta][:created].should_not be_nil
      body[:meta][:updated].should_not be_nil
      body[:meta][:schema].should eql("urn:acm:schemas:1.0")
    end

    it "should create an object with multiple types"
    it "should should create an object with no types"
    it "should not allow a permission to be assigned to an object with no types"
    it "should assign a permission to an object only if the type allows it"
  end

end
