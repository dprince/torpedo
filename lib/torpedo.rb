require 'rubygems'
require 'torpedo/config'

configs = Torpedo::Config.load_configs

SSH_TIMEOUT=(configs['ssh_timeout'] || 30).to_i
PING_TIMEOUT=(configs['ping_timeout'] || 60).to_i
SERVER_BUILD_TIMEOUT=(configs['server_build_timeout'] || 60).to_i
SSH_PRIVATE_KEY=configs['ssh_private_key'] || ENV['HOME'] + "/.ssh/id_rsa"
SSH_PUBLIC_KEY=configs['ssh_public_key'] || ENV['HOME'] + "/.ssh/id_rsa.pub"
TEST_CREATE_IMAGE=configs['test_create_image'] || false
TEST_REBUILD_SERVER=configs['test_rebuild_server'] || false
TEST_RESIZE_SERVER=configs['test_resize_server'] || false
KEYPAIR=configs['keypair']
KEYNAME=configs['keyname']

IMAGE_REF=configs['image_ref']
IMAGE_NAME=configs['image_name']

FLAVOR_REF=configs['flavor_ref']
FLAVOR_NAME=configs['flavor_name']

FLAVOR_REF_RESIZE=configs['flavor_ref_resize']
FLAVOR_NAME_RESIZE=configs['flavor_name_resize']

OPENSTACK_COMPUTE_VERSION=configs['openstack_compute_version'] || '1.1.4'

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
