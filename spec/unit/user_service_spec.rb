require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/user_service'
require 'json'

describe ACM::Services::UserService do

  before(:each) do
    @user_service = ACM::Services::UserService.new()
  end

  describe "creating a user" do

    it "will create a user without an id and assign one to it" do

      user_json = @user_service.create_user(:additional_info => {:email => "olds@vmware.com"}.to_json())

      user = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      user[:id].should_not be_nil
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

    end

    it "will create a user with an id" do

      user_json = @user_service.create_user(:id => "abc12345", :additional_info => {:email => "olds@vmware.com"}.to_json())

      user = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      user[:id].should eql("abc12345")
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

    end

    it "will not allow you to create any other type of subject" do

      user_json = @user_service.create_user(:additional_info => {:email => "olds@vmware.com"}.to_json(), :type => "random")

      user = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      user[:id].should_not be_nil
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

    end

    it "will not create a duplicate id" do

      user_json = @user_service.create_user(:id => "abc12345", :additional_info => {:email => "olds@vmware.com"}.to_json())

      user = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      user[:id].should eql("abc12345")
      user[:type].should eql(:user.to_s)
      user[:additional_info].should eql({:email => "olds@vmware.com"}.to_json())
      user[:meta][:created].should_not be_nil
      user[:meta][:updated].should_not be_nil

      lambda {
        user_json = @user_service.create_user(:id => "abc12345", :additional_info => {:email => "olds@vmware.com"}.to_json())
      }.should raise_error(ACM::SystemInternalError)

    end

  end

end