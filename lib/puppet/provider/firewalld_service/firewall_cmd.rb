# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_service).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  def self.instances
    services = execute_firewall_cmd(['--get-services'], nil).split
    services.map do |service|
      new(
        {
          ensure: :present,
          name: service,
        }
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
    if @resource[:zone] == :unset
      execute_firewall_cmd_policy(['--list-services']).split.include?(@resource[:service])
    else
      execute_firewall_cmd(['--list-services']).split.include?(@resource[:service])
    end
  end

  def create
    debug("Adding new service to firewalld: #{@resource[:service]}")
    if @resource[:zone] == :unset
      execute_firewall_cmd_policy(['--add-service', @resource[:service]])
    else
      execute_firewall_cmd(['--add-service', @resource[:service]])
    end
    reload_firewall
  end

  def destroy
    debug("Removing service from firewalld: #{@resource[:service]}")

    flag = if online?
             '--remove-service'
           else
             '--remove-service-from-zone'
           end

    if @resource[:zone] == :unset
      execute_firewall_cmd_policy([flag, @resource[:service]])
    else
      execute_firewall_cmd([flag, @resource[:service]])
    end
    reload_firewall
  end
end
