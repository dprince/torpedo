require 'rubygems'
require 'torpedo/config'

configs = Torpedo::Config.load_configs

SSH_TIMEOUT=(configs['ssh_timeout'] || 30).to_i
TEST_SSH=configs.fetch('test_ssh', true)
PING_TIMEOUT=(configs['ping_timeout'] || 60).to_i
TEST_PING=configs.fetch('test_ping', true)
SERVER_BUILD_TIMEOUT=(configs['server_build_timeout'] || 60).to_i
SLEEP_AFTER_IMAGE_CREATE=(configs['sleep_after_image_create'] || 0).to_i
SSH_PRIVATE_KEY=configs['ssh_private_key'] || ENV['HOME'] + "/.ssh/id_rsa"
SSH_PUBLIC_KEY=configs['ssh_public_key'] || ENV['HOME'] + "/.ssh/id_rsa.pub"
TEST_CREATE_IMAGE=configs['test_create_image'] || false
TEST_REBUILD_SERVER=configs['test_rebuild_server'] || false
TEST_SOFT_REBOOT_SERVER=configs['test_soft_reboot_server'] || false
TEST_HARD_REBOOT_SERVER=configs['test_hard_reboot_server'] || false
TEST_RESIZE_SERVER=configs['test_resize_server'] || false
TEST_REVERT_RESIZE_SERVER=configs['test_revert_resize_server'] || false
TEST_ADMIN_PASSWORD=configs['test_admin_password'] || false
TEST_HOSTID_ON_RESIZE=configs['test_hostid_on_resize'] || false
TEST_IP_TYPE=configs['test_ip_type'] || 4
TEST_LIMITS=configs.fetch('test_limits', true)
CLEAN_UP_SERVERS=configs.fetch('clean_up_servers', true)
CLEAN_UP_IMAGES=configs.fetch('clean_up_images', true)
KEYPAIR=configs['keypair']
KEYNAME=configs['keyname']

IMAGE_REF=configs['image_ref']
IMAGE_NAME=configs['image_name']

FLAVOR_REF=configs['flavor_ref']
FLAVOR_NAME=configs['flavor_name']

FLAVOR_REF_RESIZE=configs['flavor_ref_resize']
FLAVOR_NAME_RESIZE=configs['flavor_name_resize']

OPENSTACK_COMPUTE_VERSION=configs['openstack_compute_version']

require 'torpedo/compute/helper'

module Torpedo
class Tasks < Thor

    desc "flavors", "Run flavors tests for the OSAPI."
    def flavors
      require 'torpedo/compute/flavors'
    end

    desc "limits", "Run limits tests for the OSAPI."
    def limits
      require 'torpedo/compute/limits'
    end

    desc "images", "Run images tests for the OSAPI."
    def images
      require 'torpedo/compute/images'
    end

    desc "servers", "Run servers tests for the OSAPI."
    def servers
      require 'torpedo/compute/servers'
    end

    desc "cleanup", "Clean up servers and images (not necessary normally)."
    def cleanup
      conn = Torpedo::Compute::Helper::get_connection
      conn.servers.each do |server|
        server = conn.server(server[:id])
        if server.name == 'torpedo'
          puts 'Deleting torpedo server'
          server.delete!
        end
      end
      conn.images.each do |image|
        image = conn.image(image[:id])
        if image.server and conn.server(image.server['id']).name == 'torpedo'
          puts 'Deleting torpedo image'
          image.delete!
        end
      end
    end

    desc "all", "Run all tests."
    def all
      require 'torpedo/compute/flavors'
      require 'torpedo/compute/limits'
      require 'torpedo/compute/images'
      require 'torpedo/compute/servers'
    end

    desc "fire", "Fire away! (alias for all)"
    def fire
       invoke :all
    end

end
end
