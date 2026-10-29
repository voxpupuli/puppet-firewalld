# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_port).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  mk_resource_methods

  # Builds a Hash of zone/policy name => { 'ports' => [{'port'=>.., 'protocol'=>..}, ...], ... }
  # from a single firewall-cmd invocation. See Puppet::Provider::Firewalld.parse_list_all.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.zone_port_map
    parse_list_all(execute_firewall_cmd(['--list-all-zones'], nil))
  end

  def self.policy_port_map
    parse_list_all(execute_firewall_cmd(['--list-all-policies'], nil))
  end

  def self.instances
    found = []
    zone_port_map.each do |zone, data|
      data['ports'].each do |p|
        found << new(ensure: :present, name: "#{zone}-#{p['port']}-#{p['protocol']}", port: p['port'], protocol: p['protocol'], zone: zone, policy: :unset)
      end
    end
    policy_port_map.each do |policy, data|
      data['ports'].each do |p|
        found << new(ensure: :present, name: "#{policy}-#{p['port']}-#{p['protocol']}", port: p['port'], protocol: p['protocol'], zone: :unset, policy: policy)
      end
    end
    found
  end

  # Resources are keyed by an arbitrary Puppet title, so we can't match
  # discovered instances back to resources by name (see self.instances).
  # Instead resolve each declared resource directly against the zone/policy
  # maps gathered above.
  #
  def self.prefetch(resources)
    # Only fetch what's actually referenced, in case a catalog only uses
    # zones or only uses policies.
    zones = (resources.each_value.any? { |r| r[:zone] != :unset }) ? zone_port_map : {}
    policies = (resources.each_value.any? { |r| r[:policy] != :unset }) ? policy_port_map : {}

    resources.each_value do |resource|
      data = (resource[:zone] == :unset) ? policies[resource[:policy]] : zones[resource[:zone]]
      present = data ? data['ports'].any? { |p| p['port'] == resource[:port] && p['protocol'] == resource[:protocol] } : false
      resource.provider = new(
        ensure: present ? :present : :absent,
        name: resource[:name],
        port: resource[:port],
        protocol: resource[:protocol],
        zone: resource[:zone],
        policy: resource[:policy],
      )
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow (eg. the ad-hoc resources firewalld_zone's
  # purge_ports constructs to check and remove unmanaged ports) have no
  # prefetched state, so fall back to a live query for those.
  def exists?
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

    @rule_args ||= build_port_rule
    output = if @resource[:zone] == :unset
               execute_firewall_cmd_policy(['--query-port', @rule_args],
                                           @resource[:policy],
                                           true, false)
             else
               execute_firewall_cmd(['--query-port', @rule_args],
                                    @resource[:zone],
                                    true, false)
             end
    output.exitstatus.zero?
  end

  def quote_keyval(key, val)
    val ? "#{key}=\"#{val}\"" : ''
  end

  def eval_port
    args = []
    args << "#{@resource[:port]}/#{@resource[:protocol]}"
    args
  end

  def build_port_rule
    rule = []
    rule << eval_port
    rule
  end

  def create
    if @resource[:zone] == :unset
      execute_firewall_cmd_policy(['--add-port', build_port_rule])
    else
      execute_firewall_cmd(['--add-port', build_port_rule])
    end
  end

  def destroy
    if @resource[:zone] == :unset
      execute_firewall_cmd_policy(['--remove-port', build_port_rule])
    else
      execute_firewall_cmd(['--remove-port', build_port_rule])
    end
  end
end
