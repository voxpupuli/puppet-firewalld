# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld_dbus.rb')

Puppet::Type.type(:firewalld_port).provide(
  :dbus,
  parent: Puppet::Provider::FirewalldDbus
) do
  desc 'Interact through DBus'

  mk_resource_methods

  # rubocop:disable Naming/AccessorMethodName
  def get_ports
    dbus_resource_settings['ports'] || []
  end

  def set_ports(ports)
    dbus_update_resource_settings { 'ports' => ports }
  end
  # rubocop:enable Naming/AccessorMethodName

  def exists?
    get_ports.any? { |port| port.first == @resource[:port] && port.last == @resource[:protocol] }
  end

  def create
    ports = get_ports
    ports.push [@resource[:port], @resource[:protocol]]
    set_ports ports
    reload_firewall
  end

  def destroy
    ports = get_ports
    ports.delete [@resource[:port], @resource[:protocol]]
    set_ports ports
    reload_firewall
  end
end
