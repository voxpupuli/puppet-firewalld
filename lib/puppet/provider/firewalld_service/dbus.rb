# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld_dbus.rb')

Puppet::Type.type(:firewalld_service).provide(
  :dbus,
  parent: Puppet::Provider::FirewalldDbus
) do
  desc 'Interact through DBus'

  mk_resource_methods

  # rubocop:disable Naming/AccessorMethodName
  def get_services
    dbus_resource_settings['services'] || []
  end

  def set_services(services)
    dbus_update_resource_settings { 'services' => services }
  end
  # rubocop:enable Naming/AccessorMethodName

  def exists?
    get_services.include?(@resource[:service])
  end

  def create
    services = get_services
    services.push @resource[:service]
    set_services services
    reload_firewall
  end

  def destroy
    services = get_services
    services.delete @resource[:service]
    set_services services
    reload_firewall
  end
end
