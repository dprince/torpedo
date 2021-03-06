if RUBY_VERSION =~ /^1.9.*/ then
  gem 'test-unit'
end
require 'test/unit'
if FOG_VERSION
  gem 'fog', FOG_VERSION
end
require 'fog'

module Torpedo
  module Compute
    module Helper

      def self.get_connection

        if ENV['DEBUG'] and ENV['DEBUG'] == 'true' then
          ENV['EXCON_DEBUG'] = 'true'
        end

        if DISABLE_SSL_CHECK
          Excon.defaults[:ssl_verify_peer] = false
        end

        auth_url = ENV['NOVA_URL'] || ENV['OS_AUTH_URL']
        api_key = ENV['NOVA_API_KEY'] || ENV['OS_PASSWORD']
        username = ENV['NOVA_USERNAME'] || ENV['OS_USERNAME']
        authtenant = ENV['NOVA_PROJECT_ID'] || ENV['OS_TENANT_NAME']
        region = ENV['NOVA_REGION_NAME'] || ENV['OS_AUTH_REGION']
        service_type = ENV['NOVA_SERVICE_TYPE'] || "compute"
        service_name = ENV['NOVA_SERVICE_NAME'] #nil by default

        Fog::Compute.new(
          :provider           => :openstack,
          :openstack_auth_url  => auth_url+'/tokens',
          :openstack_username => username,
          :openstack_tenant => authtenant,
          :openstack_api_key => api_key,
          :openstack_region => region,
          :openstack_service_type => service_type,
          :openstack_service_name => service_name
        )

      end

      def self.get_image_ref(conn)

        image_ref = IMAGE_REF
        image_name = IMAGE_NAME

        if image_name and not image_name.empty? then
          images = conn.images.each do |image|
            if image.name == image_name then
              image_ref = image.id
            end
          end
        elsif image_ref.nil? or image_ref.empty? then
          #take the last image if IMAGE_REF and or IMAGE_NAME aren't set
          images = conn.images
          raise "Image list is empty." if images.empty?
          image_ref = images.last.id.to_s
        end

        image_ref

      end

      def self.get_flavor_ref(conn)

        flavor_ref = FLAVOR_REF
        flavor_name = FLAVOR_NAME

        if flavor_name and not flavor_name.empty? then
          flavors = conn.flavors.each do |flavor|
            if flavor.name == flavor_name then
              flavor_ref = flavor.id
            end
          end
        elsif not flavor_ref or flavor_ref.to_s.empty? then
          # default to 2 (m1.small) if FLAVOR_REF and or FLAVOR_NAME aren't set
          flavor_ref = 2
        end

        flavor_ref.to_s

      end

      #flavor ref used for resize
      def self.get_flavor_ref_resize(conn)

        flavor_ref_resize = FLAVOR_REF_RESIZE
        flavor_name_resize = FLAVOR_NAME_RESIZE

        if flavor_name_resize and not flavor_name_resize.empty? then
          flavors = conn.flavors.each do |flavor|
            if flavor.name == flavor_name_resize then
              flavor_ref_resize = flavor.id
            end
          end
        elsif not flavor_ref_resize or flavor_ref_resize.to_s.empty? then
          # if no flavor ref is specified for resize add one to it
          flavor_ref = Helper.get_flavor_ref(conn)
          flavor_ref_resize = flavor_ref.to_i + 1
        end

        flavor_ref_resize.to_s

      end

    end
  end
end
