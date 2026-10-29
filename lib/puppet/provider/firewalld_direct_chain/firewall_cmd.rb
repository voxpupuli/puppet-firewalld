# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_direct_chain).provide(:firewall_cmd, parent: Puppet::Provider::Firewalld) do
  desc 'Provider for managing firewalld direct chains using firewall-cmd'

  # Lists every configured direct chain with a single firewall-cmd
  # invocation. See Puppet::Provider::Firewalld.parse_all_chains.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.all_chains
    parse_all_chains(execute_firewall_cmd(['--direct', '--get-all-chains'], nil))
  end

  def self.instances
    all_chains.map do |c|
      new(ensure: :present, name: c['name'], inet_protocol: c['inet_protocol'], table: c['table'])
    end
  end

  # Resources are keyed by (inet_protocol, table, name), not by the Puppet
  # title alone (title_patterns in the type lets name be given standalone or
  # as "inet_protocol:table:name"), so discovered instances are matched
  # directly against each resource's own parameters rather than by name.
  #
  def self.prefetch(resources)
    chains = all_chains

    resources.each_value do |resource|
      present = chains.any? do |c|
        c['inet_protocol'] == resource[:inet_protocol] && c['table'] == resource[:table] && c['name'] == resource[:name]
      end
      resource.provider = new(
        ensure: present ? :present : :absent,
        name: resource[:name],
        inet_protocol: resource[:inet_protocol],
        table: resource[:table],
      )
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow have no prefetched state, so fall back to a
  # live query for those.
  def exists?
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

    @chain_args ||= generate_raw
    output = execute_firewall_cmd(['--direct', '--query-chain', @chain_args], nil, true, false)
    output.include?('yes')
  end

  def create
    @chain_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--add-chain', @chain_args], nil)
  end

  def destroy
    @chain_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--remove-chain', @chain_args], nil)
  end

  def generate_raw
    chain = []
    chain << [
      @resource[:inet_protocol],
      @resource[:table],
      @resource[:name],
    ]
  end
end
