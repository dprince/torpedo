require 'torpedo'
require 'torpedo/compute/helper'
require 'torpedo/volume/helper'


module Torpedo

  class Cleanup < Test::Unit::TestCase

    def test_999_cleanup
      if ORCHESTRATION_ENABLED and CLEAN_UP_STACKS then
        orchestration_conn = Torpedo::Orchestration::Helper::get_connection
        orchestration_conn.stacks.each do |stack|
          stack = orchestration_conn.stacks.get(stack.id)
          if stack.stack_name == 'torpedo'
            #puts 'Deleting torpedo stack'
            assert(stack.destroy)
            # We wait for the stack to be deleted here to avoid pulling
            # the rug on heat (and causing a potential log ERROR)
            begin
              timeout(STACK_CREATE_TIMEOUT) do
                until orchestration_conn.stacks.get(stack.id).nil? do
                  sleep(1)
                end
              end
            rescue Timeout::Error => te
              fail('Timeout deleting stack.')
            end

          end
        end
      end
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
      if KEYPAIR_ENABLED and CLEAN_UP_KEYPAIRS then
        compute_conn.key_pairs.each do |key_pair|
          key_pair = compute_conn.key_pairs.get(key_pair.name)
          if key_pair.name == 'torpedo'
            #puts 'Deleting torpedo key_pair'
            assert(key_pair.destroy)
          end
        end
      end
      if VOLUME_ENABLED and CLEAN_UP_VOLUMES then
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
