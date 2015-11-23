require File.dirname(__FILE__) + '/helper'

module Torpedo
  module Compute
    class Heat < Test::Unit::TestCase

      def test_001_list_cfn

        # skip right now
        return

        ec2_key = ENV['EC2_ACCESS_KEY']
        ec2_secret = ENV['EC2_SECRET_KEY']

        cf = Fog::AWS::CloudFormation.new(
          :host => "127.0.0.1",
          :port => 8000,
          :path => '/v1',
          :scheme => "http",
          :aws_access_key_id => ec2_key,
          :aws_secret_access_key => ec2_secret
        )

        cf.list_stacks()
      end

      def test_002_list_heat_api
        cf = Fog::Orchestration.new(
                 :provider => 'OpenStack',
                 :openstack_api_key => ENV['OS_PASSWORD'],
                 :openstack_username => ENV["OS_USERNAME"],
                 :openstack_auth_url => ENV["OS_AUTH_URL"] + "/tokens",
                 :openstack_tenant => ENV["OS_TENANT_NAME"]
        )
        cf.list_stacks()
      end


    end
  end
end
