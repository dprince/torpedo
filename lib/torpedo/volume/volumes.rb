require 'torpedo/volume/helper'
require 'torpedo/compute/helper'
require 'tempfile'
require 'net/ssh'

module Torpedo
  module Volume
    class Volumes < Test::Unit::TestCase

      @@volumes = []
      @@volume = nil #ref to last created volume
      @@volsize = 1
      @@volname = "torpedo"
      @@voldesc = "T0rp3d@! F1r3$"
      @@snapshot_id = nil

      # public access to the volume ref
      def self.volume
        @@volume
      end

      def setup
        @conn=Helper::get_connection
      end

      def create_volume(options)
        @@volume = @conn.volumes.create(options)
        @@volumes << @@volume
        @@volume
      end

      def check_volume(volume, check_status="available")

        volume = @conn.volumes.get(volume.id)
        assert_equal(@@volsize, volume.size)
        assert_equal(@@volname, volume.display_name)
        assert_equal(@@voldesc, volume.display_description)
        assert_equal(1, volume.size)

        begin
          timeout(VOLUME_BUILD_TIMEOUT) do
            until volume.status == check_status do
              if volume.status == "error" then
                fail('Volume ERROR status detected!')
              end
              volume = @conn.volumes.get(volume.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout creating volume.')
        end

        volume

      end

      def test_001_create_volume
        options = {:display_name => @@volname, :display_description => @@voldesc, :size => @@volsize}
        volume = create_volume(options)

        check_volume(volume)

      end

      def test_002_create_volume_snapshot

        snapshot = @conn.create_volume_snapshot(@@volume.id, "#{@@volname} snap", "#{@@voldesc} snap", true).body['snapshot']
        assert_not_nil(snapshot['id'])
        @@snapshot_id = snapshot['id']
        assert_equal(@@volume.id, snapshot['volume_id'])

        begin
          timeout(VOLUME_BUILD_TIMEOUT) do
            until snapshot['status'] == 'available' do
              if snapshot['status'] == "error" then
                fail('Volume snapshot ERROR status detected!')
              end
              snapshot = @conn.get_snapshot_details(snapshot['id']).body['snapshot']
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout creating snapshot.')
        end

      end if TEST_VOLUME_SNAPSHOTS

      def test_003_del_volume_snapshot

        assert(@conn.delete_snapshot(@@snapshot_id))

        begin
          snapcount = 1
          timeout(60) do
            until snapcount == 0 do
              snapcount = 0
              @conn.list_snapshots.body['snapshots'].each do |snap|
                if snap['name'] == "#{@@volname} snap" then
                  snapcount += 1
                  sleep 1
                end
              end
            end
          end
        rescue Timeout::Error => te
          fail('Timeout waiting for snapshot to be deleted.')
        end

      end if TEST_VOLUME_SNAPSHOTS

    end
  end
end
