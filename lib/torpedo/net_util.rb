require 'net/ssh'

module Torpedo
  class NetUtil < Test::Unit::TestCase

    def self.ssh_test(ip_addr, network_namespace, test_cmd, test_output, admin_pass)

      if network_namespace then
        out=%x{ip netns exec #{network_namespace} torpedo ssh --ip-address=#{ip_addr} --test-command='#{test_cmd}' --test-output='#{test_output}' --admin-password='#{admin_pass}'}
        retval=$?
        if retval.success? then
          return true
        else
          puts out
          return false
        end
      end

      ssh_opts = {:paranoid => false}
      if TEST_ADMIN_PASSWORD then
        ssh_opts.store(:password, admin_pass)
      else
        ssh_identity=SSH_PRIVATE_KEY
        ssh_opts.store(:keys, ssh_identity)
      end

      begin
        Timeout::timeout(SSH_TIMEOUT) do
          while(1) do
            begin
              Net::SSH.start(ip_addr, 'root', ssh_opts) do |ssh|
                  return ssh.exec!(test_cmd) == test_output
              end
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET, Net::SSH::Exception
              next
            end
          end
        end
      rescue Timeout::Error => te
        fail("Timeout trying to ssh to server: #{ip_addr}")
      end

      return false

    end

    def self.ping_test(ip_addr, network_namespace=nil)
      begin
        namespace_cmd = network_namespace.nil? ? "" : "ip netns exec #{network_namespace} "
        ping = TEST_IP_TYPE == 6 ? 'ping6' : 'ping'
        ping_command = "#{namespace_cmd}#{ping} -c 1 #{ip_addr} > /dev/null 2>&1"
        Timeout::timeout(PING_TIMEOUT) do
          while(1) do
            return true if system(ping_command)
          end
        end
      rescue Timeout::Error => te
        fail("Timeout pinging server: #{ping_command}")
      end

      return false

    end

  end
end
