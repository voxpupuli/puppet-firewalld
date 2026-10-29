# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_service).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  # Builds a Hash of zone/policy name => { 'services' => [...], ... } from a
  # single `--list-all-zones` or `--list-all-policies` invocation. This lets
  # us resolve every firewalld_service resource's state with at most two
  # firewall-cmd calls per run instead of one per resource.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.zone_service_map
    parse_list_all(execute_firewall_cmd(['--list-all-zones'], nil))
  end

  def self.policy_service_map
    parse_list_all(execute_firewall_cmd(['--list-all-policies'], nil))
  end

  # Lists services actually bound to a zone or policy. Note that unlike
  # `--get-services` (which prints firewalld's entire predefined service
  # catalog, not what's enabled anywhere) this reflects real bindings.
  #
  def self.instances
    found = []
    zone_service_map.each do |zone, data|
      data['services'].each do |service|
        found << new(ensure: :present, name: "#{zone}-#{service}", service: service, zone: zone, policy: :unset)
      end
    end
    policy_service_map.each do |policy, data|
      data['services'].each do |service|
        found << new(ensure: :present, name: "#{policy}-#{service}", service: service, zone: :unset, policy: policy)
      end
    end
    found
  end

  # Resources are keyed by an arbitrary Puppet title, not by the firewalld
  # service name, so we can't match discovered instances back to resources
  # by name (see self.instances). Instead resolve each declared resource
  # directly against the zone/policy maps gathered above.
  #
  def self.prefetch(resources)
    # Only fetch what's actually referenced, in case a catalog only uses
    # zones or only uses policies.
    zones = (resources.each_value.any? { |r| r[:zone] != :unset }) ? zone_service_map : {}
    policies = (resources.each_value.any? { |r| r[:policy] != :unset }) ? policy_service_map : {}

    resources.each_value do |resource|
      service = resource[:service]
      data = (resource[:zone] == :unset) ? policies[resource[:policy]] : zones[resource[:zone]]
      present = data ? data['services'].include?(service) : false
      resource.provider = new(
        ensure: present ? :present : :absent,
        name: resource[:name],
        service: service,
        zone: resource[:zone],
        policy: resource[:policy],
      )
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow (eg. the ad-hoc resources firewalld_zone's
  # purge_services constructs to check and remove unmanaged services) have
  # no prefetched state, so fall back to a live query for those.
  def exists?
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

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
