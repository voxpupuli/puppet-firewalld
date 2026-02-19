# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require File.join(File.dirname(__FILE__), '..', 'firewalld_dbus.rb')

Puppet::Type.type(:firewalld_policy).provide(
  :dbus,
  parent: Puppet::Provider::FirewalldDbus
) do
  desc 'Interact through DBus'

  def dbus_live_settings
    @dbus_live_settings ||= find_live_policy_settings(@resource[:name])
  end

  def settings_to_update
    @settings_to_update ||= {}
  end

  def exists?
    @resource[:policy] = @resource[:name]
    dbus_resource
  rescue DBus::Error
    false
  end

  def create
    debug("Creating new policy #{@resource[:name]} with target: '#{@resource[:target]}'")

    self.target = @resource[:target] if @resource[:target]
    self.ingress_zones = @resource[:ingress_zones]
    self.egress_zones = @resource[:egress_zones]
    self.priority = @resource[:priority] if @resource[:priority]
    self.icmp_blocks = @resource[:icmp_blocks] if @resource[:icmp_blocks]
    self.description = @resource[:description] if @resource[:description]
    self.short = @resource[:short] if @resource[:short]

    create_policy(@resource[:name], settings_to_update)
    settings_to_update.clear
  end

  def destroy
    debug("Deleting policy #{@resource[:name]}")
    dbus_resource.remove
  end

  def target
    dbus_resource_settings['target']
  end

  def target=(__target)
    debug("Setting target for policy #{@resource[:name]} to #{@resource[:target]}")
    settings_to_update['target'] = @resource[:target]
  end

  def ingress_zones
    dbus_resource_settings['ingress_zones']
  end

  def ingress_zones=(new_ingress_zones)
    settings_to_update['ingress_zones'] = (new_ingress_zones || [])
  end

  def egress_zones
    dbus_resource_settings['egress_zones']
  end

  def egress_zones=(new_egress_zones)
    settings_to_update['egress_zones'] = (new_egress_zones || [])
  end

  def priority
    dbus_resource_settings['priority']
  end

  def priority=(new_priority)
    settings_to_update['priority'] = new_priority
  end

  def masquerade
    dbus_resource_settings['masquerade'] ? :true : :false
  end

  def masquerade=(bool)
    settings_to_update['masquerade'] = bool == :true
  end

  def icmp_blocks
    dbus_resource_settings['icmp_blocks'] || []
  end

  def icmp_blocks=(new_icmp_blocks)
    icmp_types = get_icmp_types
    set_blocks = []

    case new_icmp_blocks
    when Array
      new_icmp_blocks.each do |block|
        raise Puppet::Error, 'parameter icmp_blocks must be a string or array of strings!' unless block.is_a?(String)

        if icmp_types.include?(block)
          debug("adding block #{block} to policy #{@resource[:name]}")
          set_blocks.push(block)
        else
          valid_types = icmp_types.join(', ')
          raise Puppet::Error, "#{block} is not a valid icmp type on this system! Valid types are: #{valid_types}"
        end
      end
    when String
      if icmp_types.include?(new_icmp_blocks)
        debug("adding block #{new_icmp_blocks} to policy #{@resource[:name]}")
        set_blocks.push(new_icmp_blocks)
      else
        valid_types = icmp_types.join(', ')
        raise Puppet::Error, "#{new_icmp_blocks} is not a valid icmp type on this system! Valid types are: #{valid_types}"
      end
    else
      raise Puppet::Error, 'parameter icmp_blocks must be a string or array of strings!'
    end

    settings_to_update['icmp_blocks'] = set_blocks
  end

  # rubocop:disable Style/AccessorMethodName
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
  # rubocop:enable Style/AccessorMethodName

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

    debug("Updating policy #{@resource[:name]} with #{settings_to_update}")
    dbus_update_resource_settings(settings_to_update)
    settings_to_update.clear
    @dbus_live_settings = nil

    reload_firewall
  end
end
