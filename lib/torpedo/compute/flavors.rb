require File.dirname(__FILE__) + '/helper'

module Torpedo
module Compute
class Flavors < Test::Unit::TestCase

  def setup
    @conn=Helper::get_connection
  end

  def test_list

    @conn.flavors.each do |flavor|
      assert_not_nil(flavor.id)
      assert_not_nil(flavor.name)
      assert_not_nil(flavor.ram)
      assert_not_nil(flavor.disk)
    end

  end

  def test_get

    flavor = @conn.flavors.get(1)
    assert_not_nil(flavor.id)
    assert_not_nil(flavor.name)
    assert_not_nil(flavor.ram)
    assert_not_nil(flavor.disk)

  end

end
end
end
