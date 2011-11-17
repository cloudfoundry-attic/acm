require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/user_service'
require 'json'

describe ACM::Services::UserService do

  before(:each) do
    @user_service = ACM::Services::UserService.new()
  end

  describe "creating a user" do

    it "will create a user with a valid name" do

      user_json = @user_service.create_user(:additional_info => {:email => "olds@vmware.com"}.to_json())

      user = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      user[:id].should_not be_nil
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

    end

  end

end