require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_service).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  def initialize(value = {})
    super(value)
    @exists_in_perm = false
    @exists_in_run = false
  end

  def exists?
    @exists_in_perm = execute_firewall_cmd(['--list-services']).split(' ').include?(@resource[:service])
    @exists_in_run = execute_firewall_cmd(['--list-services'], nil, false).split(' ').include?(@resource[:service])
    if @resource[:ensure] == :present
      @exists_in_perm && @exists_in_run
    else
      @exists_in_perm || @exists_in_run
    end
  end

  def create
    debug("Adding new service to firewalld: #{@resource[:service]}")
    execute_firewall_cmd(['--add-service', @resource[:service]]) unless @exists_in_perm
    reload_firewall
  end

  def destroy
    debug("Removing service from firewalld: #{@resource[:service]}")

    flag = if online?
             '--remove-service'
           else
             '--remove-service-from-zone'
           end

    execute_firewall_cmd([flag, @resource[:service]]) if @exists_in_perm
    reload_firewall
  end
end
