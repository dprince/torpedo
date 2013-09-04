if RUBY_VERSION =~ /^1.9.*/ then
  gem 'test-unit'
end
require 'test/unit'
if FOG_VERSION
  gem 'fog', FOG_VERSION
end
require 'fog'

module Torpedo
  module Metering
    module Helper

      def self.get_connection

        if ENV['DEBUG'] and ENV['DEBUG'] == 'true' then
          ENV['EXCON_DEBUG'] = 'true'
        end

        auth_url = ENV['OS_AUTH_URL']
        api_key = ENV['OS_PASSWORD']
        username = ENV['OS_USERNAME']
        authtenant = ENV['OS_TENANT_NAME']
        #region = ENV['OS_AUTH_REGION']
        service_type = ENV['CEILOMETER_SERVICE_TYPE'] || "metering"
        service_name = ENV['CEILOMETER_SERVICE_NAME'] #nil by default

        Fog::Metering.new(
          :provider           => :openstack,
          :openstack_auth_url  => auth_url+'/tokens',
          :openstack_username => username,
          :openstack_tenant => authtenant,
          :openstack_api_key => api_key,
          #:openstack_region => region,
          :openstack_service_type => service_type,
          :openstack_service_name => service_name
        )

      end

    end
  end
end
