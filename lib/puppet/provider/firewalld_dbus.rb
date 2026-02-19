# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require 'puppet/provider'

class Puppet::Provider::FirewalldDbus < Puppet::Provider
  initvars

  confine feature: :dbus
  defaultfor feature: :dbus

  def state
    debug("Firewalld state: #{firewalld_interface['state']}")
    firewalld_interface['state'] == 'RUNNING'
  rescue DBus::Error
    nil
  end

  def offline?
    state == false || state.nil?
  end

  def online?
    state == true
  end

  # Local object access
  def dbus_resource
    @dbus_resource ||= dbus_object_interface()
  end

  def dbus_resource_settings
    @dbus_resource_settings ||= begin
      debug("Retrieving settings for #{dbus_resource['name']}")
      if dbus_resource.respond_to? :getSettings2
        dbus_resource.getSettings2
      else
        dbus_resource.getSettings
      end
    end
  end

  def dbus_update_resource_settings(settings)
    debug("Updating settings for #{dbus_resource['name']}")
    @dbus_resource_settings = nil
    if dbus_resource.respond_to? :update2
      dbus_resource.update2 settings
    else
      dbus_resource.update settings
    end
  end

  # Service handling - per zone/policy
  def create_service(name, zone: nil, policy: nil)
    dbus_interface(object: dbus_object_interface(zone:, policy:).addService(name), interface: 'org.fedoraproject.FirewallD1.config.service')
  end

  def list_services(zone: nil, policy: nil)
    dbus_object_interface(zone:, policy:).listServices.map { |service| dbus_interface(object: service, interface: 'org.fedoraproject.FirewallD1.config.service') }
  end

  def find_service(name, zone: nil, policy: nil)
    dbus_interface(object: dbus_object_interface(zone:, policy:).getServiceByName(name), interface: 'org.fedoraproject.FirewallD1.config.service')
  end

  # Custom service handling - global
  def list_service_names
    firewalld_config_interface.getServiceNames
  end

  def create_custom_service(name, settings = {})
    dbus_interface(object: firewalld_config_interface.addService2(name, settings), interface: 'org.fedoraproject.FirewallD1.config.service')
  end

  # Policy handling - global
  def create_policy(name, settings = {})
    dbus_interface(object: firewalld_config_interface.addPolicy(name, settings), interface: 'org.fedoraproject.FirewallD1.config.policy')
  end

  def list_policies
    firewalld_config_interface.listPolicies.map { |zone| dbus_interface(object: zone, interface: 'org.fedoraproject.FirewallD1.config.policy') }
  end

  def find_policy(name)
    dbus_interface(object: firewalld_config_interface.getPolicyByName(name), interface: 'org.fedoraproject.FirewallD1.config.policy')
  end

  def find_live_policy_settings(name)
    dbus_interface.getPolicySettings(name)
  end

  # Zone handling - global
  def create_zone(name, settings = {})
    dbus_interface(object: firewalld_config_interface.addZone2(name, settings), interface: 'org.fedoraproject.FirewallD1.config.zone')
  end

  def find_zone(name)
    dbus_interface(object: firewalld_config_interface.getZoneByName(name), interface: 'org.fedoraproject.FirewallD1.config.zone')
  end

  def find_live_zone_settings(name)
    firewalld_interface.getServiceSettings2(name)
  end

  def find_default_zone
    find_zone(firewalld_config_interface.getDefaultZone)
  end

  # Global data helpers

  # rubocop:disable Naming/AccessorMethodName
  def get_icmp_types
    firewalld_config_interface.getIcmpTypeNames
  end
  # rubocop:enable Naming/AccessorMethodName

  def reload_firewall
    debug("Reloading firewall")
    firewalld_interface.reload
  end

  # Arguments should be parsed as separate array entities, but quoted arg
  # eg --log-prefix 'IPTABLES DROPPED' should include the whole quoted part
  # in one element
  #
  def parse_args(args)
    args = args.flatten.join(' ') if args.is_a?(Array)
    args.split(%r{('[^']*'| )}).reject { |r| ['', ' '].include?(r) }
  end

  def self.version?(version)
    require 'dbus'

    running = SemanticPuppet::Version.parse(dbus_connection['/org/fedoraproject/FirewallD1']['org.fedoraproject.FirewallD1']['version'])
    # debug("Checking for firewalld version #{running} #{version}")
    SemanticPuppet::VersionRange.parse(version).include?(running)
  rescue LoadError
    nil
  rescue DBus::Error => ex
    debug("Failed to check firewalld version - #{ex.class}: #{ex}")
    nil
  end

  protected

  def self.dbus_connection
    require 'dbus'

    @service ||= DBus.system_bus['org.fedoraproject.FirewallD1']
  end

  def dbus_connection
    self.class.dbus_connection
  end

  def self.dbus_interface(object:, interface:)
    dbus_connection[object][interface]
  end

  def dbus_interface(object:, interface:)
    self.class.dbus_interface(object:, interface:)
  end

  def dbus_object_interface(zone: nil, policy: nil)
    zone ||= @resource[:zone]
    return find_zone(zone) if zone

    policy ||= @resource[:policy]
    return find_policy(policy) if policy

    firewalld_config_interface
  end

  def self.firewalld_interface
    @firewalld_interface ||= dbus_interface(object: '/org/fedoraproject/FirewallD1', interface: 'org.fedoraproject.FirewallD1')
  end

  def firewalld_interface
    self.class.firewalld_interface
  end

  def self.firewalld_config_interface
    @firewalld_config_interface ||= dbus_interface(object: '/org/fedoraproject/FirewallD1/config', interface: 'org.fedoraproject.FirewallD1.config')
  end

  def firewalld_config_interface
    self.class.firewalld_config_interface
  end
end
