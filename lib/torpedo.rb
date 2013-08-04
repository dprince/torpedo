require 'rubygems'
require 'torpedo/config'

if RUBY_VERSION =~ /^1.9.*/ then
  gem 'test-unit'
end
require 'test/unit'
require 'test/unit/ui/console/testrunner'

configs = Torpedo::Config.load_configs

SSH_TIMEOUT=(configs['ssh_timeout'] || 30).to_i
TEST_SSH=configs.fetch('test_ssh', true)
PING_TIMEOUT=(configs['ping_timeout'] || 60).to_i
TEST_PING=configs.fetch('test_ping', true)
SERVER_BUILD_TIMEOUT=(configs['server_build_timeout'] || 60).to_i
NETWORK_LABEL=(configs['network_label'] || 'public')
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
CLEAN_UP_KEYPAIRS=configs.fetch('clean_up_keypairs', true)
KEYPAIR_ENABLED = configs.fetch('keypairs', false)

IMAGE_REF=configs['image_ref']
IMAGE_NAME=configs['image_name']

FLAVOR_REF=configs['flavor_ref']
FLAVOR_NAME=configs['flavor_name']

FLAVOR_REF_RESIZE=configs['flavor_ref_resize']
FLAVOR_NAME_RESIZE=configs['flavor_name_resize']

#volume opts
volume_opts=configs['volumes'] || {}
VOLUME_ENABLED = volume_opts.fetch('enabled', false)
VOLUME_BUILD_TIMEOUT = (volume_opts['build_timeout'] || 60).to_i
TEST_VOLUME_SNAPSHOTS = volume_opts.fetch('test_snapshots', false)
CLEAN_UP_VOLUMES = volume_opts.fetch('cleanup', true)

FOG_VERSION=configs['fog_version']

TORPEDO_TEST_SUITE = Test::Unit::TestSuite.new("Torpedo")
module Torpedo

  class TorpedoTests
    def self.suite
      return TORPEDO_TEST_SUITE
    end
  end

  class Tasks < Thor

    desc "flavors", "Run flavors tests for the OSAPI."
    def flavors
      require 'torpedo/compute/flavors'
      TORPEDO_TEST_SUITE << Torpedo::Compute::Flavors.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "limits", "Run limits tests for the OSAPI."
    def limits
      require 'torpedo/compute/limits'
      TORPEDO_TEST_SUITE << Torpedo::Compute::Limits.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "images", "Run images tests for the OSAPI."
    def images
      require 'torpedo/compute/images'
      TORPEDO_TEST_SUITE << Torpedo::Compute::Images.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "servers", "Run servers tests for the OSAPI."
    def servers
      require 'torpedo/volume/volumes'
      require 'torpedo/compute/keypairs'
      require 'torpedo/compute/servers'
      require 'torpedo/cleanup'
      if VOLUME_ENABLED
        TORPEDO_TEST_SUITE << Torpedo::Volume::Volumes.suite
      end
      if KEYPAIR_ENABLED
        TORPEDO_TEST_SUITE << Torpedo::Compute::Keypairs.suite
      end
      TORPEDO_TEST_SUITE << Torpedo::Compute::Servers.suite
      TORPEDO_TEST_SUITE << Torpedo::Cleanup.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "keypairs", "Run keypair tests for the OSAPI."
    def keypairs
      require 'torpedo/compute/keypairs'
      require 'torpedo/cleanup'
      TORPEDO_TEST_SUITE << Torpedo::Compute::Keypairs.suite
      TORPEDO_TEST_SUITE << Torpedo::Cleanup.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "volumes", "Run volume tests for the OSAPI."
    def volumes
      require 'torpedo/volume/volumes'
      require 'torpedo/cleanup'
      TORPEDO_TEST_SUITE << Torpedo::Volume::Volumes.suite
      TORPEDO_TEST_SUITE << Torpedo::Cleanup.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "cleanup", "Clean up servers, images, volumes, etc."
    def cleanup
      require 'torpedo/cleanup'
      TORPEDO_TEST_SUITE << Torpedo::Cleanup.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "all", "Run all tests."
    def all
      require 'torpedo/compute/keypairs'
      require 'torpedo/compute/flavors'
      require 'torpedo/compute/limits'
      require 'torpedo/compute/images'
      require 'torpedo/volume/volumes'
      require 'torpedo/compute/servers'
      require 'torpedo/cleanup'
      if KEYPAIR_ENABLED
        TORPEDO_TEST_SUITE << Torpedo::Compute::Keypairs.suite
      end
      TORPEDO_TEST_SUITE << Torpedo::Compute::Flavors.suite
      TORPEDO_TEST_SUITE << Torpedo::Compute::Limits.suite
      TORPEDO_TEST_SUITE << Torpedo::Compute::Images.suite
      if VOLUME_ENABLED
        TORPEDO_TEST_SUITE << Torpedo::Volume::Volumes.suite
      end
      TORPEDO_TEST_SUITE << Torpedo::Compute::Servers.suite
      TORPEDO_TEST_SUITE << Torpedo::Cleanup.suite
      exit Test::Unit::UI::Console::TestRunner.run(TorpedoTests).passed?
    end

    desc "fire", "Fire away! (alias for all)"
    def fire
       invoke :all
    end

  end
end
