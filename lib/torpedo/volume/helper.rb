if RUBY_VERSION =~ /^1.9.*/ then
  gem 'test-unit'
end
require 'test/unit'
if FOG_VERSION
  gem 'fog', FOG_VERSION
end
require 'fog'

module Torpedo
module Volume
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
    service_type = ENV['CINDER_SERVICE_TYPE'] || "volume"
    service_name = ENV['CINDER_SERVICE_NAME'] #nil by default

    #:openstack_auth_url  => 'http://10.16.17.4:5000/v2.0/tokens',

    Fog::Volume.new(
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
