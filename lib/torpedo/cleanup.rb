require 'torpedo'
require 'torpedo/compute/helper'
require 'torpedo/volume/helper'


module Torpedo

  class Cleanup < Test::Unit::TestCase

    def test_999_cleanup
      compute_conn = Torpedo::Compute::Helper::get_connection
      if CLEAN_UP_SERVERS
        compute_conn.servers.each do |server|
          server = compute_conn.servers.get(server.id)
          if server.name == 'torpedo'
            #puts 'Deleting torpedo server'
            assert(server.destroy)
          end
        end
      end
      if CLEAN_UP_IMAGES
        compute_conn.images.each do |image|
          image = compute_conn.images.get(image.id)
          if image.name == 'torpedo'
            #puts 'Deleting torpedo image'
            assert(image.destroy)
          end
        end
      end
      if CLEAN_UP_VOLUMES
        volume_conn = Torpedo::Volume::Helper::get_connection
        volume_conn.volumes.each do |volume|
          volume = volume_conn.volumes.get(volume.id)
          if volume.display_name == 'torpedo'
            #puts 'Deleting torpedo volume'
            assert(volume.destroy)
          end
        end
      end
    end

  end
end
