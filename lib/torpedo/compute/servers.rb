require File.dirname(__FILE__) + '/helper'
require 'tempfile'
require 'net/ssh'

module Torpedo
module Compute
class Servers < Test::Unit::TestCase

  @@servers = []
  @@images = []
  @@image_ref = Helper::get_image_ref(Helper::get_connection)
  @@flavor_ref = Helper::get_flavor_ref(Helper::get_connection)
  @@flavor_ref_resize = Helper::get_flavor_ref_resize(@conn)
  @@server = nil #ref to last created server
  @@hostname = "torpedo"

  def setup
    @conn=Helper::get_connection
  end

  def create_server(server_opts)
    @@server = @conn.create_server(server_opts)
    @@servers << @@server
    @@admin_pass = @@server.adminPass #original admin_pass
    @@host_id = @@server.hostId #original host ID
    @@server
  end

  def create_image(server, image_opts)
    image = server.create_image(image_opts)
    @@images << image
    @@image_ref = image.id
    image
  end

  def get_personalities
    if TEST_ADMIN_PASSWORD then
      tmp_file=Tempfile.new "server_tests"
      tmp_file.write("yo")
      tmp_file.flush
      {tmp_file.path => "/tmp/foo/bar"}
    else
      # NOTE: if admin_pass is disabled we inject the public key so we still
      # can still login. This would only matter if KEYPAIR was disabled as well.
      {SSH_PUBLIC_KEY => "/root/.ssh/authorized_keys"}
    end
  end

  def ssh_test(ip_addr, test_cmd="hostname", test_output=@@hostname, admin_pass=@@admin_pass)

    ssh_opts = {:paranoid => false}
    if TEST_ADMIN_PASSWORD then
      ssh_opts.store(:password, admin_pass)
    else
      ssh_identity=SSH_PRIVATE_KEY
      if KEYPAIR and not KEYPAIR.empty? then
        ssh_identity=KEYPAIR
      end
      ssh_opts.store(:keys, ssh_identity)
    end

    begin
      Timeout::timeout(SSH_TIMEOUT) do
        while(1) do
          begin
            Net::SSH.start(ip_addr, 'root', ssh_opts) do |ssh|
                return ssh.exec!(test_cmd) == test_output
            end
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::SSH::Exception
            next
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
    assert_equal(@@hostname, server.name)
    server = @conn.server(server.id)

    begin
      timeout(SERVER_BUILD_TIMEOUT) do
        until server.status == check_status do
          if server.status == "ERROR" then
            fail('Server ERROR state detected when booting server!')
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
    ping_test(v4_addresses[0].address) if TEST_PING
    if TEST_SSH
      if TEST_ADMIN_PASSWORD
        ssh_test(v4_addresses[0].address, "cat /tmp/foo/bar", "yo")
      else
        ssh_test(v4_addresses[0].address)
      end
    end

    server

  end

  def test_001_create_server

    metadata={ "key1" => "value1", "key2" => "value2" }
    options = {:name => @@hostname, :imageRef => @@image_ref, :flavorRef => @@flavor_ref, :personality => get_personalities, :metadata => metadata}
    if KEYNAME and not KEYNAME.empty? then
      options[:key_name] = KEYNAME
    end
    server = create_server(options)
    assert_not_nil(server.adminPass)

    #boot a server and check it
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
    metadata['foo0'] = 'bar0'
    assert metadata.update('foo0')

    metadata.refresh

    assert_equal 'bar0', metadata['foo0']

    assert_equal 1, metadata.size
 
  end

  def test_004_update_some_server_metadata_items

    metadata = @@server.metadata
    metadata.clear
    metadata['foo1'] = 'bar1'
    metadata['foo2'] = 'bar2'
    assert metadata.update()

    metadata.refresh

    assert_equal 'bar0', metadata['foo0']
    assert_equal 'bar1', metadata['foo1']
    assert_equal 'bar2', metadata['foo2']

    assert_equal 3, metadata.size
 
  end

  def test_005_set_server_metadata_items

    metadata = @@server.metadata
    metadata.clear
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

  def test_030_rebuild
    # NOTE: this will use the snapshot if TEST_CREATE_IMAGE is enabled
    @@server.rebuild!(:adminPass => @@admin_pass, :imageRef => @@image_ref, :personality => get_personalities)
    server = @conn.server(@@server.id)
    sleep 15 # sleep a couple seconds until rebuild starts
    check_server(server, @@image_ref, @@flavor_ref)

  end if TEST_REBUILD_SERVER

  def test_035_soft_reboot
    # make sure our snapshot boots
    @@server.reboot(type='SOFT')
    server = @conn.server(@@server.id)
    assert_equal('REBOOT', server.status)
    check_server(server, @@image_ref, @@flavor_ref)
  end if TEST_SOFT_REBOOT_SERVER

  def test_036_hard_reboot
    # make sure our snapshot boots
    @@server.reboot(type='HARD')
    server = @conn.server(@@server.id)
    assert_equal('HARD_REBOOT', server.status)
    check_server(server, @@image_ref, @@flavor_ref)
  end if TEST_HARD_REBOOT_SERVER

  def test_037_change_password
    @@admin_pass = "AnGrYbIrD$"
    @@server.change_password!(@@admin_pass)
    server = @conn.server(@@server.id)
    begin
      timeout(60) do
        until server.status == 'ACTIVE' do
          server = @conn.server(server.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout changing server password.')
    end
    check_server(server, @@image_ref, @@flavor_ref)
  end if TEST_ADMIN_PASSWORD

  def test_040_resize_revert

    @@server.resize!(@@flavor_ref_resize)
    server = @conn.server(@@server.id)
    assert_equal('RESIZE', server.status)

    begin
      timeout(SERVER_BUILD_TIMEOUT) do
        until server.status == 'VERIFY_RESIZE' do
          if server.status == "ERROR" then
            fail('Server ERROR state detected when resizing server!')
          end
          server = @conn.server(server.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout resizing server.')
    end
 
    check_server(server, @@image_ref, @@flavor_ref_resize, 'VERIFY_RESIZE')

    @@server.revert_resize!
    server = @conn.server(@@server.id)
    begin
      timeout(60) do
        until server.status == 'ACTIVE' do
          server = @conn.server(server.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout waiting for revert resize.')
    end

    check_server(server, @@image_ref, @@flavor_ref)
    assert_equal(server.hostId, @@host_id)

  end if TEST_REVERT_RESIZE_SERVER

  def test_041_resize

    @@server.resize!(@@flavor_ref_resize)
    server = @conn.server(@@server.id)
    assert_equal('RESIZE', server.status)

    begin
      timeout(SERVER_BUILD_TIMEOUT) do
        until server.status == 'VERIFY_RESIZE' do
          if server.status == "ERROR" then
            fail('Server ERROR state detected when resizing server!')
          end
          server = @conn.server(server.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout resizing server.')
    end
 
    check_server(server, @@image_ref, @@flavor_ref_resize, 'VERIFY_RESIZE')
    assert_not_equal(server.hostId, @@host_id) if TEST_HOSTID_ON_RESIZE

  end if TEST_RESIZE_SERVER

  def test_042_resize_confirm

    @@server.confirm_resize!
    server = @conn.server(@@server.id)
    assert_equal('ACTIVE', server.status)

    check_server(server, @@image_ref, @@flavor_ref_resize)

  end if TEST_RESIZE_SERVER

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
    if CLEAN_UP_SERVERS
      @@servers.each do |server|
        assert_equal(true, server.delete!)
      end
    end
    if CLEAN_UP_IMAGES
      @@images.each do |image|
        assert_equal(true, image.delete!)
      end
    end
  end

end
end
end
