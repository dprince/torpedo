require 'torpedo/orchestration/helper'
require 'torpedo/compute/helper'
require 'torpedo/compute/keypairs'
require 'torpedo/compute/servers'
require 'tempfile'
require 'net/ssh'

module Torpedo
  module Orchestration
    class Stacks < Test::Unit::TestCase

      @@stack = nil
      @@image_ref = nil
      @@flavor_ref = nil

      def setup
        @conn=Helper::get_connection
        @compute_conn=Torpedo::Compute::Helper::get_connection
      end

      def test_001_setup

        assert KEYPAIR_ENABLED == true, "Keyairs should be enabled when running Orchestration tests."

        begin
          @@image_ref = Torpedo::Compute::Servers.image_ref
          if @@image_ref.nil? then
            @@image_ref = Torpedo::Compute::Helper::get_image_ref(@compute_conn)
          end
        rescue Exception => e
          fail("Failed get image ref: #{e.message}")
        end
        begin
          @@flavor_ref = Torpedo::Compute::Servers.flavor_ref
          if @@flavor_ref.nil? then
            @@flavor_ref = Torpedo::Compute::Helper::get_flavor_ref(@compute_conn)
          end
        rescue Exception => e
          fail("Failed get flavor ref: #{e.message}")
        end

      end

      def test_002_create_stack

        template = File.join(File.dirname(__FILE__), "test_server.hot")
        keypair_name = Torpedo::Compute::Keypairs.key_pair.name
        stack_opts = {
          :template => IO.read(template),
          :timeout_mins => (STACK_CREATE_TIMEOUT/60),
          :parameters => {
            :server_name => 'torpedo',
            :key_name => keypair_name,
            :image => @@image_ref,
            :flavor => @@flavor_ref
          }
        }
        stack_data = @conn.create_stack('torpedo', stack_opts).body['stack']

        stack = @conn.stacks.get(stack_data['id'])
        @@stack = stack
        assert_equal "CREATE_IN_PROGRESS", stack.stack_status

        begin
           timeout(STACK_CREATE_TIMEOUT) do
             until stack.stack_status == 'CREATE_COMPLETE' do
               if stack.stack_status =~ /FAILED/ then
                 fail('Failure status detected when creating stack!')
               end
               stack = @conn.stacks.get(stack.id)
               sleep 1
             end
           end
         rescue Timeout::Error => te
           fail('Timeout creating stack.')
         end

      end

      def test_003_update_stack

        template = File.join(File.dirname(__FILE__), "test_server.hot")
        keypair_name = Torpedo::Compute::Keypairs.key_pair.name
        stack_opts = {
          :template => IO.read(template),
          # update just the stack timeout
          :timeout_mins => (STACK_CREATE_TIMEOUT/60)+1,
          :parameters => {
            :server_name => 'torpedo',
            :key_name => keypair_name,
            :image => @@image_ref,
            :flavor => @@flavor_ref
          }
        }
        @conn.update_stack(@@stack.id, @@stack.stack_name, stack_opts).body['stack']
        stack = @conn.stacks.get(@@stack.id)
        assert_equal "UPDATE_IN_PROGRESS", stack.stack_status

        begin
          timeout(STACK_CREATE_TIMEOUT) do
            until stack.stack_status == 'UPDATE_COMPLETE' do
              if stack.stack_status =~ /FAILED/ then
                fail('Failure status detected when updating stack!')
              end
              stack = @conn.stacks.get(stack.id)
              sleep 1
            end
          end
        rescue Timeout::Error => te
          fail('Timeout updating stack.')
        end

      end

    end
  end
end
