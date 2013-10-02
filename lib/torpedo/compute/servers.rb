require 'torpedo/compute/helper'
require 'torpedo/compute/keypairs'
require 'torpedo/volume/helper'
require 'torpedo/net_util'
require 'tempfile'

module Torpedo
  module Compute
    class Servers < Test::Unit::TestCase

      @@servers = []
      @@images = []
      @@image_ref = nil
      @@flavor_ref = nil
      @@flavor_ref_resize = nil
      @@server = nil #ref to last created server
      @@hostname = "torpedo"
      @@host_id = nil

      # public access to the server ref
      def self.server
        @@server
      end

      # public access to the image ref
      def self.image_ref
        @@image_ref
      end

      # public access to the flavor ref
      def self.flavor_ref
        @@flavor_ref
      end

      def setup
        @conn=Helper::get_connection
        if VOLUME_ENABLED then
          @volume_conn=Torpedo::Volume::Helper::get_connection
        end
      end

      def create_server(options)
        if ORCHESTRATION_ENABLED then
          #if heat is enabled we re-use the server from the stack
          @conn.servers.each do |server|
            if server.name == 'torpedo'
              @@server = @conn.servers.get(server.id)
            end
            #NOTE: When using Heat we use keypairs... so just stub this out
            @@admin_pass = 'Not Available'
          end
        else
          @@server = @conn.servers.create(options)
          @@servers << @@server
          @@admin_pass = @@server.password #original admin_pass
          assert_not_nil(@@admin_pass)
        end
        @@server
      end

      def create_image(server, name, metadata)
        image_raw = @conn.create_image(server.id, name, metadata).body['image']
        image_raw[:service] = @conn
        image = Fog::Compute::OpenStack::Image.new(image_raw)
        @@images << image
        @@image_ref = image_raw['id']
        image
      end

      def get_personalities
        if TEST_ADMIN_PASSWORD or Keypairs.key_pair then
          [{'contents' => 'yo', 'path' => '/tmp/foo.bar'}]
        else
          # NOTE: if admin_pass and keypairs are disabled we inject the public
          # key so we can still login.
          [{'contents' => IO.read(SSH_PUBLIC_KEY), 'path' => '/root/.ssh/authorized_keys'}]
        end
      end

      def find_ip(server)
        # lookup the first public IP address and use that for verification
        if server.addresses[NETWORK_LABEL].nil?
          fail("No address found for network label #{NETWORK_LABEL}. Addresses: #{server.addresses}")
        end
        addresses = server.addresses[NETWORK_LABEL].select {|a| a['version'] == TEST_IP_TYPE}
        address = addresses[0]['addr']
        if address.nil? or address.empty? then
          fail("No address found for network label #{NETWORK_LABEL}. Addresses: #{server.addresses}")
        end
        address
      end

      def check_server(server, image_ref, flavor_ref, check_status="ACTIVE")

        server_flavor = server.flavor_ref || server.flavor['id']
        server_image = server.image_ref || server.image['id']

        assert_equal(flavor_ref, server_flavor)
        assert_equal(image_ref.to_s, server_image)
        assert_equal(@@hostname, server.name)
        server = @conn.servers.get(server.id)

        begin
          timeout(SERVER_BUILD_TIMEOUT) do
            until server.state == check_status do
              if server.state == "ERROR" then
                fail('Server ERROR state detected when booting server!')
              end
              server = @conn.servers.get(server.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout creating server.')
        end

        assert_not_nil(server.host_id)

        address = find_ip(server)
        Torpedo::NetUtil.ping_test(address, NETWORK_NAMESPACE) if TEST_PING
        if TEST_SSH
          if TEST_ADMIN_PASSWORD or Keypairs.key_pair then
            Torpedo::NetUtil.ssh_test(address, NETWORK_NAMESPACE, "cat /tmp/foo.bar", "yo", @@admin_pass)
          else
            Torpedo::NetUtil.ssh_test(address, NETWORK_NAMESPACE, "hostname", @@hostname, @@admin_pass)
          end
        end

        server

      end

      def test_000_setup
        begin
          @@image_ref = Helper::get_image_ref(Helper::get_connection)
        rescue Exception => e
          fail("Failed get image ref: #{e.message}")
        end
        begin
          @@flavor_ref = Helper::get_flavor_ref(Helper::get_connection)
        rescue Exception => e
          fail("Failed get flavor ref: #{e.message}")
        end
        begin
          @@flavor_ref_resize = Helper::get_flavor_ref_resize(@conn)
        rescue Exception => e
          fail("Failed get flavor ref resize: #{e.message}")
        end
      end

      def test_001_create_server

        metadata={ "key1" => "value1", "key2" => "value2" }
        options = {:name => @@hostname, :image_ref => @@image_ref, :flavor_ref => @@flavor_ref, :personality => get_personalities, :metadata => metadata}
        if Keypairs.key_pair then
          options['key_name'] = Keypairs.key_pair.name
        end
        server = create_server(options)

        #boot a server and check it
        check_server(server, @@image_ref, @@flavor_ref)

        assert_equal "value1", @@server.metadata.get('key1').value
        assert_equal "value2", @@server.metadata.get('key2').value
        assert_equal 2, @@server.metadata.size

      end

      def test_002_delete_server_metadata_items

        @@metadata = Fog::Compute::OpenStack::Metadata.new({
          :service => @conn,
          :parent => @@server
        })
        assert_equal 2, @@metadata.size

        @@metadata.each do |meta|
          assert meta.destroy
        end

        #refresh the metadata
        @@metadata = Fog::Compute::OpenStack::Metadata.new({
          :service => @conn,
          :parent => @@server
        })
        assert_equal 0, @@metadata.size

      end

      def test_003_update_one_server_metadata_item

        datum = Fog::Compute::OpenStack::Metadatum.new({
          :service => @conn,
          :parent => @@server
        })
        datum.key = 'foo0'
        datum.value = 'bar0'
        datum.save

        #refresh the metadata
        @@metadata = Fog::Compute::OpenStack::Metadata.new({
          :service => @conn,
          :parent => @@server
        })
        assert_equal 1, @@metadata.size

        datum = @@metadata[0]
        assert_equal 'foo0', datum.key
        assert_equal 'bar0', datum.value

      end


      def test_004_update_some_server_metadata_items

        metadata = {}
        metadata['foo1'] = 'bar1'
        metadata['foo2'] = 'bar2'
        @conn.update_metadata('servers', @@server.id, metadata)

        metadata = @conn.list_metadata('servers', @@server.id).body['metadata']

        assert_equal 3, metadata.size

        assert_equal 'bar0', metadata['foo0']
        assert_equal 'bar1', metadata['foo1']
        assert_equal 'bar2', metadata['foo2']

      end


      def test_005_set_server_metadata_items

        metadata = {}
        metadata['foo1'] = 'better'
        metadata['foo2'] = 'watch'
        metadata['foo3'] = 'out!'
        metadata['foo4'] = 'DELETE FROM instance_metadata;'
        @conn.set_metadata('servers', @@server.id, metadata)

        metadata = @conn.list_metadata('servers', @@server.id).body['metadata']

        assert_equal 'better', metadata['foo1']
        assert_equal 'watch', metadata['foo2']
        assert_equal 'out!', metadata['foo3']
        assert_equal 'DELETE FROM instance_metadata;', metadata['foo4']

        assert_equal 4, metadata.size
 
      end

      def test_006_clear_server_metadata

        metadata = {}
        @conn.set_metadata('servers', @@server.id, metadata)

        metadata = @conn.list_metadata('servers', @@server.id).body['metadata']
        assert_equal 0, metadata.size
 
      end


      def test_020_create_image

        #snapshot the image
        image = create_image(@@server, "torpedo", {"key1" => "value1"})

        assert_equal('SAVING', image.status)
        assert_equal('torpedo', image.name)
        assert_equal(25, image.progress)
        #FIXME: server id should be a uuid string
        assert_equal(@@server.id, image.server['id'])
        assert_not_nil(image.created_at)
        assert_not_nil(image.id)
        assert_equal "value1", image.metadata.get('key1').value

        begin
          timeout(SERVER_BUILD_TIMEOUT) do
            until image.status == 'ACTIVE' do
              image = @conn.images.get(image.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout creating image snapshot.')
        end

        sleep SLEEP_AFTER_IMAGE_CREATE

        # Overwrite image_ref to make all subsequent tests use this snapshot
        @@image_ref = image.id.to_s

      end if TEST_CREATE_IMAGE


      def test_030_rebuild
        # NOTE: this will use the snapshot if TEST_CREATE_IMAGE is enabled
        metadata={ "dr." => "evil", "big" => "boy" }
        @conn.rebuild_server(@@server.id, @@image_ref, "torpedo", admin_pass=@@admin_pass, metadata=metadata, personality=get_personalities)

        server = @conn.servers.get(@@server.id)
        assert_equal('REBUILD', server.state)

        check_server(server, @@image_ref, @@flavor_ref)

      end if TEST_REBUILD_SERVER

      def test_035_soft_reboot
        # make sure our snapshot boots
        @@server.reboot(type='SOFT')
        server = @conn.servers.get(@@server.id)
        assert_equal('REBOOT', server.state)
        check_server(server, @@image_ref, @@flavor_ref)
      end if TEST_SOFT_REBOOT_SERVER


      def test_036_hard_reboot
        # make sure our snapshot boots
        @@server.reboot(type='HARD')
        server = @conn.servers.get(@@server.id)
        assert_equal('HARD_REBOOT', server.state)
        check_server(server, @@image_ref, @@flavor_ref)
      end if TEST_HARD_REBOOT_SERVER

      def test_037_change_password
        @@admin_pass = "AnGrYbIrD$"
        @@server.change_password(@@admin_pass)
        server = @conn.servers.get(@@server.id)
        begin
          timeout(60) do
            until server.state == 'ACTIVE' do
              server = @conn.servers.get(@@server.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout changing server password.')
        end
        check_server(server, @@image_ref, @@flavor_ref)
      end if TEST_ADMIN_PASSWORD

      def test_040_resize_revert

        # before resizing obtain host_id
        server = @conn.servers.get(@@server.id)
        @@host_id = server.host_id #original host ID

        @@server.resize(@@flavor_ref_resize)
        server = @conn.servers.get(@@server.id)
        assert_equal('RESIZE', server.state)

        begin
          timeout(SERVER_BUILD_TIMEOUT) do
            until server.state == 'VERIFY_RESIZE' do
              if server.state == "ERROR" then
                fail('Server ERROR state detected when resizing server!')
              end
              server = @conn.servers.get(@@server.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout resizing server.')
        end
 
        check_server(server, @@image_ref, @@flavor_ref_resize, 'VERIFY_RESIZE')

        @@server.revert_resize
        server = @conn.servers.get(@@server.id)
        begin
          timeout(60) do
            until server.state == 'ACTIVE' do
              server = @conn.servers.get(@@server.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout waiting for revert resize.')
        end

        check_server(server, @@image_ref, @@flavor_ref)
        assert_equal(@@host_id, server.host_id)

      end if TEST_REVERT_RESIZE_SERVER

      def test_041_resize

        # before resizing obtain host_id
        server = @conn.servers.get(@@server.id)
        @@host_id = server.host_id #original host ID

        @@server.resize(@@flavor_ref_resize)
        server = @conn.servers.get(@@server.id)
        assert_equal('RESIZE', server.state)

        begin
          timeout(SERVER_BUILD_TIMEOUT) do
            until server.state == 'VERIFY_RESIZE' do
              if server.state == "ERROR" then
                fail('Server ERROR state detected when resizing server!')
              end
              server = @conn.servers.get(@@server.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout resizing server.')
        end
 
        check_server(server, @@image_ref, @@flavor_ref_resize, 'VERIFY_RESIZE')
        assert_not_equal(@@host_id, server.host_id) if TEST_HOSTID_ON_RESIZE

      end if TEST_RESIZE_SERVER

      def test_042_resize_confirm

        @@server.confirm_resize
        server = @conn.servers.get(@@server.id)
        begin
          timeout(60) do
            until server.state == 'ACTIVE' do
              server = @conn.servers.get(@@server.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout waiting for ACTIVE state after resize confirm.')
        end

        check_server(server, @@image_ref, @@flavor_ref_resize)

      end if TEST_RESIZE_SERVER

      def test_051_delete_image_metadata_items

        #refresh the metadata
        metadata = Fog::Compute::OpenStack::Metadata.new({
          :service => @conn,
          :parent => @@images.last
        })

        metadata.each do |meta|
          assert meta.destroy
        end

        #refresh the metadata
        metadata = Fog::Compute::OpenStack::Metadata.new({
          :service => @conn,
          :parent => @@images.last
        })
        assert_equal 0, metadata.size

      end if TEST_CREATE_IMAGE

      def test_052_update_one_image_metadata_item
        datum = Fog::Compute::OpenStack::Metadatum.new({
          :service => @conn,
          :parent => @@images.last
        })
        datum.key = 'foo0'
        datum.value = 'bar0'
        datum.save

        #refresh the metadata
        metadata = Fog::Compute::OpenStack::Metadata.new({
          :service => @conn,
          :parent => @@images.last
        })
        assert_equal 1, metadata.size

        datum = metadata[0]
        assert_equal 'foo0', datum.key
        assert_equal 'bar0', datum.value
      end if TEST_CREATE_IMAGE

      def test_053_update_some_image_metadata_items

        metadata = {}
        metadata['foo0'] = 'barz'
        metadata['foo1'] = 'bar1'
        metadata['foo2'] = 'bar2'
        @conn.update_metadata('images', @@images.last.id, metadata)

        metadata = @conn.list_metadata('images', @@images.last.id).body['metadata']

        assert_equal 3, metadata.size

        assert_equal 'barz', metadata['foo0']
        assert_equal 'bar1', metadata['foo1']
        assert_equal 'bar2', metadata['foo2']
 
      end if TEST_CREATE_IMAGE

      def test_054_set_image_metadata_items

        metadata = {}
        metadata['foo1'] = 'that'
        metadata['foo2'] = 'silly'
        metadata['foo3'] = 'rabbit'
        metadata['foo4'] = 'DELETE FROM images;'
        @conn.set_metadata('images', @@images.last.id, metadata)

        metadata = @conn.list_metadata('images', @@images.last.id).body['metadata']

        assert_equal 'that', metadata['foo1']
        assert_equal 'silly', metadata['foo2']
        assert_equal 'rabbit', metadata['foo3']
        assert_equal 'DELETE FROM images;', metadata['foo4']

        assert_equal 4, metadata.size
 
      end if TEST_CREATE_IMAGE

      def test_055_clear_image_metadata

        metadata = {}
        @conn.set_metadata('images', @@images.last.id, metadata)

        metadata = @conn.list_metadata('images', @@images.last.id).body['metadata']
        assert_equal 0, metadata.size
 
      end if TEST_CREATE_IMAGE

      def test_060_attach_volume
        volume = Torpedo::Volume::Volumes.volume
        assert(@@server.attach_volume(volume.id, "/dev/vdb"))

        begin
          timeout(VOLUME_BUILD_TIMEOUT) do
            until volume.status == 'in-use' do
              if volume.status == "error" then
                fail('ERROR status detected when attaching volume!')
              end
              volume = @volume_conn.volumes.get(volume.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout attaching volume.')
        end

      end if VOLUME_ENABLED

      def test_061_detach_volume

        volume = Torpedo::Volume::Volumes.volume
        assert(@@server.detach_volume(volume.id))

        volume = @volume_conn.volumes.get(volume.id)
        begin
          timeout(VOLUME_BUILD_TIMEOUT) do
            until volume.status == 'available' do
              if volume.status == "error" then
                fail('ERROR status detected when detaching volume!')
              end
              volume = @volume_conn.volumes.get(volume.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout detaching volume.')
        end

      end if VOLUME_ENABLED

    end
  end
end
