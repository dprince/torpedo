require 'test-unit-ext'
require 'test/unit'
gem 'openstack-compute', OPENSTACK_COMPUTE_VERSION
require 'openstack/compute'

module Torpedo
module Compute
module Helper

  def self.get_connection
    debug = false
    if ENV['DEBUG'] and ENV['DEBUG'] == 'true' then
        debug = true
    end
    OpenStack::Compute::Connection.new(:username => USERNAME, :api_key => API_KEY, :auth_url => API_URL, :is_debug => debug)
  end

  def self.get_image_ref(conn)

    image_ref = IMAGE_REF
    image_name = IMAGE_NAME

    if image_name and not image_name.empty? then
      images = conn.images.each do |image|
        if image[:name] == image_name then
          image_ref = image[:id]
        end
      end
    elsif image_ref.nil? or image_ref.empty? then
      #take the last image if IMAGE_REF and or IMAGE_NAME aren't set
      images = conn.images.sort{|x,y| x[:id] <=> y[:id]}
      image_ref = images.last[:id].to_s
    end

    image_ref

  end

  def self.get_flavor_ref(conn)

    flavor_ref = FLAVOR_REF
    flavor_name = FLAVOR_NAME

    if flavor_name and not flavor_name.empty? then
      flavors = conn.flavors.each do |flavor|
        if flavor[:name] == flavor_name then
          flavor_ref = flavor[:id]
        end
      end
    elsif not flavor_ref or flavor_ref.to_s.empty? then
      # default to 2 (m1.small) if FLAVOR_REF and or FLAVOR_NAME aren't set
      flavor_ref = 2
    end

    flavor_ref.to_s

  end

  #flavor ref used for resize
  def self.get_flavor_ref_resize(conn)

    flavor_ref_resize = FLAVOR_REF_RESIZE
    flavor_name_resize = FLAVOR_NAME_RESIZE

    if flavor_name_resize and not flavor_name_resize.empty? then
      flavors = conn.flavors.each do |flavor|
        if flavor[:name] == flavor_name_resize then
          flavor_ref_resize = flavor[:id]
        end
      end
    elsif not flavor_ref_resize or flavor_ref_resize.to_s.empty? then
      # if no flavor ref is specified for resize add one to it
      flavor_ref = Helper.get_flavor_ref(conn)
      flavor_ref_resize = flavor_ref.to_i + 1
    end

    flavor_ref_resize.to_s

  end

end
end
end
