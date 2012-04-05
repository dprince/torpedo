require File.dirname(__FILE__) + '/helper'

module Torpedo
module Compute
class Limits < Test::Unit::TestCase

  def setup
    @conn=Helper::get_connection
  end

  def test_list

    assert_not_nil @conn.limits

  end

end if TEST_LIMITS
end
end
