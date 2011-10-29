require 'yaml'

module Torpedo
  module Config

    @@configs=nil

    def self.load_configs
      return @@configs if not @@configs.nil?

      config_file=ENV['TORPEDO_CONFIG_FILE']
      if config_file.nil? then

        config_file=ENV['HOME']+File::SEPARATOR+".torpedo.conf"
        if not File.exists?(config_file) then
          config_file="/etc/torpedo.conf"
        end

      end

      if File.exists?(config_file) then
        configs = YAML.load_file(config_file) || {}
        @@configs = configs
      else
        raise "Failed to load torpedo config file. Please configure /etc/torpedo.conf or create a .torpedo.conf config file in your HOME directory."
      end

      @@configs

    end

    def self.raise_if_nil_or_empty(options, key)
      if not options or options[key].nil? or options[key].empty? then
        raise "Please specify a valid #{key.to_s} parameter."
      end
    end

  end
end
