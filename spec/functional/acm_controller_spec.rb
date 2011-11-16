require File.expand_path("../../spec_helper", __FILE__)

require "rack/test"

describe ACM::Controller do
  include Rack::Test::Methods

  describe "object management" do

    def payload(params)
      { "CONTENT_TYPE" => "application/json", :input => Yajl::Encoder.encode(params)}
    end

    it "will raise an exception if the object id does not exist" do

    end
  end

end
