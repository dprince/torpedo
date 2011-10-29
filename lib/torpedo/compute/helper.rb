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

    image_ref = ENV['IMAGE_REF']
    image_name = ENV['IMAGE_NAME']

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

end
end
end
