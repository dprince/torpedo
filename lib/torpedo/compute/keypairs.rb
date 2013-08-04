require File.dirname(__FILE__) + '/helper'

module Torpedo
  module Compute
    class Keypairs < Test::Unit::TestCase

      @@key_pairs = []
      @@key_pair = nil #ref to last created key_pair
      @@key_pair_name = 'torpedo' #ref to last created key_pair

      # public access to the key_pair ref
      def self.key_pair
        @@key_pair
      end

      def setup
        @conn=Helper::get_connection
      end

      def create_key_pair(options)
        @@key_pair = @conn.key_pairs.create(options)
        @@key_pairs << @@key_pair
        @@key_pair
      end

      def test_001_create_key_pair
        public_key = IO.read(SSH_PUBLIC_KEY)
        options = {:public_key => public_key, :name => @@key_pair_name}
        key_pair = create_key_pair(options)
        assert_equal(@@key_pair_name, key_pair.name)
        assert_equal(public_key, key_pair.public_key)
      end

    end
  end
end
