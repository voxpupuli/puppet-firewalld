# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld_dbus.rb')

Puppet::Type.type(:firewalld_custom_service).provide(
  :dbus,
  parent: Puppet::Provider::FirewalldDbus
) do
  # When the getSettings2/updated2 method was added
  confine true: Puppet::Provider::FirewalldDbus.version?('>= 0.8.0')

  desc 'Interact through DBus'

  def self.instances
    services = firewalld_config_interface.listServices.map { |obj| dbus_interface(object: obj, interface: 'org.fedoraproject.FirewallD1.config.service') }
    services.reject! { |svc_obj| svc_obj['builtin'] || !svc_obj.respond_to?(:getSettings2) }
    services.map do |svc_obj|
      new(
        ensure: :present,
        name: svc_obj['name'],
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

  def dbus_resource
    @dbus_resource ||= dbus_interface(
      object: firewalld_config_interface.getServiceByName(@resource[:name]),
      interface: 'org.fedoraproject.FirewallD1.config.service'
    )
  end

  def settings_to_update
    @settings_to_update ||= {}
  end

  def exists?
    begin
      dbus_resource
    rescue DBus::Error
      return false
    end

    builtin = dbus_resource['builtin']
    return false if builtin && (@resource[:ensure] == :absent)

    true
  end

  def create
    debug("Adding new custom service to firewalld: #{@resource[:name]}")

    send(:short=, @resource[:short]) if @resource[:short]
    send(:description=, @resource[:description]) if @resource[:description]
    ports && send(:ports=, @resource[:ports]) unless @resource[:ports].include?(:unset)
    protocols && send(:protocols=, @resource[:protocols]) unless @resource[:protocols].include?(:unset)
    modules && send(:modules=, @resource[:modules]) unless @resource[:modules].include?(:unset)
    send(:ipv4_destination=, @resource[:ipv4_destination]) unless @resource[:ipv4_destination] == :unset
    send(:ipv6_destination=, @resource[:ipv6_destination]) unless @resource[:ipv6_destination] == :unset

    create_custom_service(@resource[:name], settings_to_update)
    settings_to_update.clear

    reload_firewall
  end

  def destroy
    settings_to_update.clear
    if dbus_resource['builtin']
      dbus_resource.loadDefaults
    else
      dbus_resource.remove
    end

    reload_firewall
  end

  def short
    dbus_resource_settings['short']
  end

  def short=(should)
    settings_to_update['short'] = should
  end

  def description
    dbus_resource_settings['description']
  end

  def description=(should)
    settings_to_update['description'] = should
  end

  def ports
    (dbus_resource_settings['ports'] || []).map do |entry|
      { 'port' => entry.first, 'protocol' => entry.last }
    end
  end

  def ports=(should)
    settings_to_update['ports'] = should&.map { |port| [port['port'] || '', port['protocol']] } || []
  end

  def protocols
    (dbus_resource_settings['protocols'] || [])
  end

  def protocols=(should)
    settings_to_update['protocols'] = should || []
  end

  def modules
    (dbus_resource_settings['modules'] || [])
  end

  def modules=(should)
    settings_to_update['modules'] = should || []
  end

  def ipv4_destination
    (dbus_resource_settings['destination'] || {})['ipv4'] || ''
  end

  def ipv4_destination=(should)
    (settings_to_update['destination'] ||= dbus_resource_settings['destination'] || {})['ipv4'] = should
  end

  def ipv6_destination
    (dbus_resource_settings['destination'] || {})['ipv6'] || ''
  end

  def ipv6_destination=(should)
    (settings_to_update['destination'] ||= dbus_resource_settings['destination'] || {})['ipv6'] = should
  end

  def flush
    return unless settings_to_update.any?

    dbus_formatted = settings_to_update.to_h { |k, v| [k, v.nil? ? '' : v] }
    dbus_formatted['destination']&.delete_if { |k, v| v.nil? || v == :unset || v.empty? }

    debug("Updating custom service #{@resource[:name]} with #{dbus_formatted}")
    dbus_update_resource_settings(dbus_formatted)
    settings_to_update.clear

    reload_firewall
  end
end
