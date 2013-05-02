require File.dirname(__FILE__) + '/helper'

module Torpedo
module Compute
class Limits < Test::Unit::TestCase

  def setup
    @conn=Helper::get_connection
  end

  def test_list

    limits = @conn.get_limits.body['limits']
    assert_not_nil limits
    assert_not_nil limits['rate']
    assert_not_nil limits['absolute']

  end

end if TEST_LIMITS
end
end
