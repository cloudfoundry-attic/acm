require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/object_service'
require 'json'

describe ACM::Services::ObjectService do

  before(:each) do
    @object_service = ACM::Services::ObjectService.new()
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

      o_json = @object_service.create_object(:additional_info => {:created_by => :cloud_controller}.to_json())

      object = Yajl::Parser.parse(o_json, :symbolize_keys => true)

      object[:id].should_not be_nil
      object[:type].should be_nil
      object[:meta][:created].should_not be_nil
      object[:meta][:updated].should_not be_nil
      object[:additional_info].should eql({:created_by => :cloud_controller}.to_json())

    end


  end

end