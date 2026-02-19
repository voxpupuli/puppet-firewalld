# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld_dbus.rb')

Puppet::Type.type(:firewalld_ipset).provide(
  :dbus,
  parent: Puppet::Provider::FirewalldDbus
) do
  # When the object type was added
  confine true: Puppet::Provider::FirewalldDbus.version?('>= 0.4.0')

  desc 'Interact through DBus'

  mk_resource_methods

  def self.instances
    ipsets = firewalld_config_interface.listIPSets
    ipsets.map do |ipset_obj|
      ipset = dbus_interface(object: ipset_obj, interface: 'org.fedoraproject.FirewallD1.config.ipset')

      new(
        {
          ensure: :present,
          name: ipset['name'],
          type: ipset.getType,
        }.merge(ipset.getOptions.transform_keys(&:to_sym))
      )
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def exists?
    dbus_ipset

    true
  rescue DBus::Error
    false
  end

  def dbus_ipset
    @dbus_ipset ||= dbus_interface(
      object: firewalld_config_interface.getIPSetByName(@resource[:name]),
      interface: 'org.fedoraproject.FirewallD1.config.ipset'
    )
  end

  def create
    settings = []
    settings << "" # version
    settings << @resource[:name]
    settings << "" # description
    settings << @resource[:type]
    settings << build_options
    settings << (@resource[:manage_entries] ? (@resource[:entries] || []) : [])

    firewalld_config_interface.addIPSet @resource[:name], *settings
  end

  %i[maxelem family hashsize timeout].each do |method|
    define_method("#{method}=") do |should|
      dbus_ipset.setOptions build_options
      @property_hash[method] = should
    end
  end

  def type
    dbus_ipset.getType
  end

  def type=(new_type)
    dbus_ipset.setType new_type
  end

  def type
    dbus_ipset.getType
  end

  def type=(new_type)
    dbus_ipset.setType new_type
  end

  def entries
    if @resource[:manage_entries]
      dbus_ipset.getEntries
    else
      @resource[:entries]
    end
  end

  def entries=(should_entries)
    unless @resource[:manage_entries]
      debug("Not managing entries for ipset #{@resource[:name]}")
      return
    end

    dbus_ipset.setEntries should_entries
  end

  def build_options
    options = {
      'family' => @resource[:family],
      'hashsize' => @resource[:hashsize],
      'maxelem' => @resource[:maxelem],
      'timeout' => @resource[:timeout]
    }
    options = options.merge(@resource[:options]) if @resource[:options]
    options.compact.transform_values(&:to_s)
  end

  def destroy
    dbus_ipset.remove
  end

  def flush
    reload_firewall
  end
end
