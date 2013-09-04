require 'torpedo/metering/helper'
require 'torpedo/compute/helper'
require 'tempfile'
require 'net/ssh'

module Torpedo
  module Metering
    class Meters < Test::Unit::TestCase

      def setup
        @conn=Helper::get_connection
        @compute_conn=Torpedo::Compute::Helper::get_connection
      end

      def wait_sample_ready(sample_name, resource_id)
        begin

          timeout(METERING_SAMPLE_TIMEOUT) do

            sample_count = 0
            until sample_count > 0 do
              @conn.get_samples(sample_name).body.each do |sample|
                if sample['resource_id'] == resource_id then
                  sample_count += 1
                end
              end
            end

          end

        rescue Timeout::Error => te
          fail('Timeout waiting for metering sample data.')
        end

      end

      def test_001_check_meters
        @conn.list_meters.body.each do |meter|
          assert_not_nil meter['name']
          assert_not_nil meter['user_id']
          assert_not_nil meter['resource_id']
          assert_not_nil meter['project_id']
          assert_not_nil meter['type']
          assert_not_nil meter['unit']
        end
      end

      def test_002_check_compute_memory_samples

        server = Torpedo::Compute::Servers.server
        server_flavor = server.flavor_ref || server.flavor['id']
        flavor = @compute_conn.flavors.get(server_flavor)

        wait_sample_ready('memory', server.id)

        @conn.get_samples('memory').body.each do |sample|
          if sample['resource_id'] == server.id then
            # convert to a float so they match
            assert_equal flavor.ram.to_f.to_s, sample['counter_volume'].to_s
          end
        end

      end

    end
  end
end
