require File.expand_path("../../spec_helper", __FILE__)

require "rack/test"

describe ACM::Controller::RackController do
  include Rack::Test::Methods

  before(:each) do
    @logger = ACM::Config.logger
  end

  def app
    @app ||= ACM::Controller::RackController.new
  end

  describe "api authentication" do

    it "requires auth" do
      get "/"
      last_response.status.should eql(401)
      @logger.debug("Auth response #{last_response.inspect}")
    end

    it "allows correct credentials" do
      basic_authorize "admin", "password"
      get "/"
      last_response.status.should eql(404)
      @logger.debug("Auth response #{last_response.inspect}")
    end

    it "should not allow incorrect credentials" do
      basic_authorize "admin", "password1234"
      get "/"
      last_response.status.should eql(401)
      @logger.debug("Auth response #{last_response.inspect}")
    end

  end

end
