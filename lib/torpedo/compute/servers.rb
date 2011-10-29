require File.dirname(__FILE__) + '/helper'
require 'tempfile'

module Torpedo
module Compute
class Servers < Test::Unit::TestCase

  @@servers = []
  @@images = []
  @@image_ref = Helper::get_image_ref(Helper::get_connection)
  @@flavor_ref = Helper::get_flavor_ref(Helper::get_connection)
  @@server = nil #ref to last created server

  def setup
    @conn=Helper::get_connection
  end

  def create_server(server_opts)
    @@server = @conn.create_server(server_opts)
    @@servers << @@server
    @@server
  end

  def create_image(server, image_opts)
    image = server.create_image(image_opts)
    @@images << image
    @@image_ref = image.id
    image
  end

  def ssh_test(ip_addr)
    begin
      Timeout::timeout(SSH_TIMEOUT) do

        while(1) do
          ssh_identity=SSH_PRIVATE_KEY
          if KEYPAIR and not KEYPAIR.empty? then
              ssh_identity=KEYPAIR
          end
          if system("ssh -o StrictHostKeyChecking=no -i #{ssh_identity} root@#{ip_addr} /bin/true > /dev/null 2>&1") then
            return true
          end
        end

      end
    rescue Timeout::Error => te
      fail("Timeout trying to ssh to server: #{ip_addr}")
    end

    return false

  end

  def ping_test(ip_addr)
    begin
      Timeout::timeout(PING_TIMEOUT) do

        while(1) do
          if system("ping -c 1 #{ip_addr} > /dev/null 2>&1") then
            return true
          end
        end

      end
    rescue Timeout::Error => te
      fail("Timeout pinging server: #{ip_addr}")
    end

    return false

  end

  def check_server(server, image_ref, flavor_ref, check_status="ACTIVE")

    assert_not_nil(server.hostId)
    assert_equal(flavor_ref, server.flavor['id'])
    assert_equal(image_ref.to_s, server.image['id'])
    assert_equal('test1', server.name)
    server = @conn.server(server.id)

    begin
      timeout(SERVER_BUILD_TIMEOUT) do
        until server.status == check_status do
          if server.status == "ERROR" then
            fail('Server ERROR state detected when booting instance!')
          end
          server = @conn.server(server.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout creating server.')
    end

    # lookup the first IPv4 address and use that for verification
    v4_addresses = server.addresses[:public].reject {|addr| addr.version != 4}
    ping_test(v4_addresses[0].address)
    ssh_test(v4_addresses[0].address)

    server

  end

  def test_001_create_server

    # NOTE: When using AMI style images we rely on keypairs for SSH access.
    
    # NOTE: injecting two or more files doesn't work for now due to XenStore
    # limitations
    personalities={SSH_PUBLIC_KEY => "/root/.ssh/authorized_keys"}
    metadata={ "key1" => "value1", "key2" => "value2" }
    options = {:name => "test1", :imageRef => @@image_ref, :flavorRef => @@flavor_ref, :personality => personalities, :metadata => metadata}
    if KEYNAME and not KEYNAME.empty? then
      options[:key_name] = KEYNAME
    end
    server = create_server(options)
    assert_not_nil(@@server.adminPass)

    #boot an instance and check it
    check_server(server, @@image_ref, @@flavor_ref)

    assert_equal "value1", @@server.metadata['key1']
    assert_equal "value2", @@server.metadata['key2']
    assert_equal 2, @@server.metadata.size

  end

  def test_002_delete_server_metadata_items

    metadata = @@server.metadata
    metadata.each_pair do |key, value|
      assert metadata.delete!(key)
    end
 
    metadata.refresh

    assert_equal 0, metadata.size

  end

  def test_003_update_one_server_metadata_item

    metadata = @@server.metadata
    metadata['foo1'] = 'bar1'
    assert metadata.update('foo1')

    metadata.refresh

    assert_equal 'bar1', metadata['foo1']

    assert_equal 1, metadata.size
 
  end

  def test_004_update_some_server_metadata_items

    metadata = @@server.metadata
    metadata['foo1'] = 'bar1'
    metadata['foo2'] = 'bar2'
    assert metadata.update(['foo1','foo2'])

    metadata.refresh

    assert_equal 'bar1', metadata['foo1']
    assert_equal 'bar2', metadata['foo2']

    assert_equal 2, metadata.size
 
  end

  def test_005_set_server_metadata_items

    metadata = @@server.metadata
    metadata['foo1'] = 'better'
    metadata['foo2'] = 'watch'
    metadata['foo3'] = 'out!'
    assert metadata.save

    metadata.refresh

    assert_equal 'better', metadata['foo1']
    assert_equal 'watch', metadata['foo2']
    assert_equal 'out!', metadata['foo3']

    assert_equal 3, metadata.size
 
  end

  def test_006_clear_server_metadata

    metadata = @@server.metadata
    assert metadata.clear!

    metadata.refresh

    assert_equal 0, metadata.size
 
  end

  def test_020_create_image

    #snapshot the image
    image = create_image(@@server, :name => "My Backup", :metadata => {"key1" => "value1"})
    assert_equal('SAVING', image.status)
    assert_equal('My Backup', image.name)
    assert_equal(25, image.progress)
    #FIXME: server id should be a uuid string
    assert_equal(@@server.id.to_s, image.server['id'])
    assert_not_nil(image.created)
    assert_not_nil(image.id)
    assert_equal('value1', image.metadata['key1'])

    begin
      timeout(SERVER_BUILD_TIMEOUT) do
        until image.status == 'ACTIVE' do
          image = @conn.image(image.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout creating image snapshot.')
    end

    # Overwrite image_ref to make all subsequent tests use this snapshot
    @@image_ref = image.id.to_s

  end if TEST_CREATE_IMAGE

 
  def test_030_rebuild_instance
    # make sure our snapshot boots
    personalities={SSH_PUBLIC_KEY => "/root/.ssh/authorized_keys"}
    @@server.rebuild!(:imageRef => @@image_ref, :personality => personalities)
    server = @conn.server(@@server.id)
    sleep 15 # sleep a couple seconds until rebuild starts
    check_server(server, @@image_ref, @@flavor_ref)

  end if TEST_REBUILD_SERVER

  def test_040_resize_instance

    flavor_ref_resize = Helper::get_flavor_ref_resize(@conn)

    @@server.resize!(flavor_ref_resize)
    server = @conn.server(@@server.id)
    assert_equal('RESIZE', @@server.status)

    begin
      timeout(SERVER_BUILD_TIMEOUT) do
        until server.status == 'VERIFY_RESIZE' do
          if server.status == "ERROR" then
            fail('Server ERROR state detected when resizing instance!')
          end
          server = @conn.server(@@server.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout resizing server.')
    end
 
    check_server(server, @@image_ref, flavor_ref_resize, 'VERIFY_RESIZE')

    server.confirm_resize!
    server = @conn.server(@@server.id)
    assert_equal('ACTIVE', @@server.status)

    check_server(server, @@image_ref, flavor_ref_resize)

  end if TEST_RESIZE_SERVER

  #NOTE: we do image metadata tests last because they will make the
  # snapshot un-bootable (they removed needed metadata)
  def test_051_delete_image_metadata_items

    metadata = @conn.image(@@image_ref).metadata
    metadata.each_pair do |key, value|
      assert metadata.delete!(key)
    end
 
    metadata.refresh

    assert_equal 0, metadata.size

  end if TEST_CREATE_IMAGE

  def test_052_update_one_image_metadata_item

    metadata = @conn.image(@@image_ref).metadata
    metadata['foo1'] = 'bar1'
    assert metadata.update('foo1')

    metadata.refresh

    assert_equal 'bar1', metadata['foo1']

    assert_equal 1, metadata.size
 
  end if TEST_CREATE_IMAGE

  def test_053_update_some_image_metadata_items

    metadata = @conn.image(@@image_ref).metadata
    metadata['foo1'] = 'bar1'
    metadata['foo2'] = 'bar2'
    assert metadata.update(['foo1','foo2'])

    metadata.refresh

    assert_equal 'bar1', metadata['foo1']
    assert_equal 'bar2', metadata['foo2']

    assert_equal 2, metadata.size
 
  end if TEST_CREATE_IMAGE

  def test_054_set_image_metadata_items

    metadata = @conn.image(@@image_ref).metadata
    metadata['foo1'] = 'that'
    metadata['foo2'] = 'silly'
    metadata['foo3'] = 'rabbit'
    assert metadata.save

    metadata.refresh

    assert_equal 'that', metadata['foo1']
    assert_equal 'silly', metadata['foo2']
    assert_equal 'rabbit', metadata['foo3']

    assert_equal 3, metadata.size
 
  end if TEST_CREATE_IMAGE

  def test_055_clear_image_metadata

    metadata = @conn.image(@@image_ref).metadata
    assert metadata.clear!

    metadata.refresh

    assert_equal 0, metadata.size
 
  end if TEST_CREATE_IMAGE

  def test_999_teardown
    @@servers.each do |server|
      assert_equal(true, server.delete!)
    end
    @@images.each do |image|
      assert_equal(true, image.delete!)
    end
  end

end
end
end
