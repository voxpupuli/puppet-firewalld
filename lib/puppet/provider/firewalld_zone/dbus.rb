# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require File.join(File.dirname(__FILE__), '..', 'firewalld_dbus.rb')

Puppet::Type.type(:firewalld_zone).provide(
  :dbus,
  parent: Puppet::Provider::FirewalldDbus
) do
  # When the getSettings2/update2 methods were added
  confine true: Puppet::Provider::FirewalldDbus.version?('>= 0.9.0')

  desc 'Interact through DBus'

  def self.instances
    zones = firewalld_config_interface.listZones.map { |obj| dbus_interface(object: obj, interface: 'org.fedoraproject.FirewallD1.config.zone') }
    zones.select! { |zone_obj| zone_obj.respond_to? :getSettings2 }
    zones.map do |zone_obj|
      new(
        {
          ensure: :present,
          name: zone_obj['name'],
        }
      )
    end
  end

  def dbus_resource
    @dbus_resource ||= dbus_interface(
      object: firewalld_config_interface.getZoneByName(@resource[:name]),
      interface: 'org.fedoraproject.FirewallD1.config.zone'
    )
  end

  def dbus_live_settings
    @dbus_live_settings ||= find_live_zone_settings(@resource[:name])
  end

  def settings_to_update
    @settings_to_update ||= {}
  end

  def exists?
    @resource[:zone] = @resource[:name]
    dbus_resource
  rescue DBus::Error
    false
  end

  def create
    debug("Creating new zone #{@resource[:name]} with target: '#{@resource[:target]}'")

    self.target = @resource[:target] if @resource[:target]
    self.sources = @resource[:sources] if @resource[:sources]
    self.protocols = @resource[:protocols] if @resource[:protocols]
    self.interfaces = @resource[:interfaces]
    self.icmp_blocks = @resource[:icmp_blocks] if @resource[:icmp_blocks]
    self.icmp_block_inversion = @resource[:icmp_block_inversion] if @resource[:icmp_block_inversion]
    self.description = @resource[:description] if @resource[:description]
    self.short = @resource[:short] if @resource[:short]

    create_zone(@resource[:name], settings_to_update)
    settings_to_update.clear
    reload_firewall
  end

  def destroy
    debug("Deleting zone #{@resource[:name]}")
    settings_to_update.clear
    @dbus_live_settings = nil

    dbus_resource.remove
  end

  def target
    dbus_resource_settings['target']
  end

  def target=(__target)
    debug("Setting target for zone #{@resource[:name]} to #{@resource[:target]}")
    settings_to_update['target'] = @resource[:target]
  end

  def interfaces
    dbus_resource_settings['interfaces']
  end

  def interfaces=(new_interfaces)
    settings_to_update['interfaces'] = (new_interfaces || [])
  end

  def sources
    dbus_resource_settings['sources']
  end

  def sources=(new_sources)
    settings_to_update['sources'] = (new_sources || [])
  end

  def protocols
    dbus_resource_settings['protocols']
  end

  def protocols=(new_protocols)
    settings_to_update['protocols'] = (new_protocols || [])
  end

  def masquerade
    dbus_resource_settings['masquerade'] ? :true : :false
  end

  def masquerade=(bool)
    settings_to_update['masquerade'] = (bool == :true)
  end

  def icmp_blocks
    dbus_resource_settings['icmp_blocks'] || []
  end

  def icmp_blocks=(new_icmp_blocks)
    new_icmp_blocks = new_icmp_blocks.split(%r{\s+}) if new_icmp_blocks.is_a?(String)
    raise Puppet::Error, 'parameter icmp_blocks must be a string or array of strings!' unless new_icmp_blocks.is_a?(Array)

    icmp_types = get_icmp_types
    invalid_blocks = new_icmp_blocks - icmp_types
    raise Puppet::Error, "Invalid ICMP types: '#{invalid_blocks.join(', ')}'! Valid types are: '#{icmp_types.join(', ')}'" unless invalid_blocks.empty?

    settings_to_update['icmp_blocks'] = new_icmp_blocks
  end

  def icmp_block_inversion
    dbus_resource_settings['icmp_block_inversion'] ? :true : :false
  end

  def icmp_block_inversion=(bool)
    settings_to_update['icmp_block_inversion'] = (bool == :true)
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_rules
    perm = dbus_resource_settings['rich_rules'] || []
    curr = dbus_live_settings['rich_rules'] || []
    [perm, curr].flatten.uniq
  end

  def get_services
    perm = dbus_resource_settings['rich_rules'] || []
    curr = dbus_live_settings['rich_rules'] || []
    [perm, curr].flatten.uniq
  end

  def get_ports
    perm = dbus_resource_settings['rich_rules'] || []
    curr = dbus_live_settings['rich_rules'] || []

    [perm, curr].flatten.uniq.map do |entry|
      port, protocol = *entry
      debug("get_ports() Found port #{port} protocol #{protocol}")
      { 'port' => port, 'protocol' => protocol }
    end
  end
  # rubocop:enable Naming/AccessorMethodName

  def description
    dbus_resource_settings['description']
  end

  def description=(new_description)
    settings_to_update['description'] = new_description
  end

  def short
    dbus_resource_settings['short']
  end

  def short=(new_short)
    settings_to_update['short'] = new_short
  end

  def flush
    return unless settings_to_update.any?

    debug("Updating zone #{@resource[:name]} with #{settings_to_update}")
    dbus_update_resource_settings(settings_to_update)
    settings_to_update.clear
    @dbus_live_settings = nil

    reload_firewall
  end
end
