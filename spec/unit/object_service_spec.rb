require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/object_service'

describe ACM::Services::ObjectService do

  before(:each) do
    @object_service = ACM::Services::ObjectService.new()
  end

  describe ACM::Services::ObjectService, "in creating an object" do

    it "will create an object with a valid name" do

      @object_service.create_object(:name => "www_staging")

    end


  end

end