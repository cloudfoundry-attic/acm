require File.expand_path("../../spec_helper", __FILE__)

require 'acm/services/group_service'
require 'json'

describe ACM::Services::GroupService do

  before(:each) do

    @user_service = ACM::Services::UserService.new()
    @group_service = ACM::Services::GroupService.new()

    @group1 = SecureRandom.uuid

    @user1 = SecureRandom.uuid
    @user2 = SecureRandom.uuid
    @user3 = SecureRandom.uuid
    @user4 = SecureRandom.uuid

    @logger = ACM::Config.logger
  end

  describe "creating a group" do

    it "should create an empty group given a unique id" do

      group_json = @group_service.create_group(:id => @group1, :additional_info => "Developer group")

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group[:id].should eql(@group1)
      group[:members].should be_nil
      group[:additional_info].should eql("Developer group")

      group[:meta][:created].should_not be_nil
      group[:meta][:updated].should_not be_nil

    end

    it "should create a group correctly given a unique id and a set of members" do

      group_json = @group_service.create_group(:id => @group1,
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group[:id].should eql(@group1)
      group[:members].sort().should eql([@user1, @user2, @user3, @user4].sort())
      group[:additional_info].should eql("Developer group")

      group[:meta][:created].should_not be_nil
      group[:meta][:updated].should_not be_nil

    end

    it "should be possible to create a group without an id" do

      group_json = @group_service.create_group()

      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      group[:id].should_not be_nil
      group[:members].should be_nil
      group[:additional_info].should be_nil

      group[:meta][:created].should_not be_nil
      group[:meta][:updated].should_not be_nil

    end

    it "should not be possible to create a group with an existing name" do

      group_json = @group_service.create_group(:id => @group1,
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])

      lambda {
        group_json = @group_service.create_group(:id => @group1)
      }.should raise_error(ACM::InvalidRequest)

    end

  end

  describe "fetching a group" do

    it "should return the group requested" do

      group_json = @group_service.create_group(:id => @group1,
                                              :additional_info => "Developer group",
                                              :members => [@user1, @user2, @user3, @user4])
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)

      fetched_group_json = @group_service.find_group(group[:id])
      fetched_group = Yajl::Parser.parse(fetched_group_json, :symbolize_keys => true)

      fetched_group.should eql(group)

    end

  end

end
