# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_direct_passthrough).provide(
  :firewalld_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  # Lists every configured direct passthrough with a single firewall-cmd
  # invocation. See Puppet::Provider::Firewalld.parse_all_passthroughs.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.all_passthroughs
    parse_all_passthroughs(execute_firewall_cmd(['--direct', '--get-all-passthroughs'], nil))
  end

  def self.instances
    all_passthroughs.map do |p|
      new(ensure: :present, name: p['args'].join(' '), inet_protocol: p['inet_protocol'], args: p['args'].join(' '))
    end
  end

  # Resources are keyed by an arbitrary Puppet title, so we can't match
  # discovered instances back to resources by name (see self.instances).
  # Instead each declared resource's args are tokenized the same way
  # generate_raw does, and matched directly against the passthroughs
  # gathered above.
  #
  def self.prefetch(resources)
    passthroughs = all_passthroughs

    resources.each_value do |resource|
      provider = resource.provider
      args = provider.parse_args(resource[:args]).map { |a| a.delete("'") }
      present = passthroughs.any? do |p|
        p['inet_protocol'] == resource[:inet_protocol] && p['args'] == args
      end
      resource.provider = new(
        ensure: present ? :present : :absent,
        name: resource[:name],
        inet_protocol: resource[:inet_protocol],
        args: resource[:args],
      )
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow have no prefetched state, so fall back to a
  # live query for those.
  def exists?
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

    @passt_args ||= generate_raw
    output = execute_firewall_cmd(['--direct', '--query-passthrough', @passt_args], nil, true, false)
    output.include?('yes')
  end

  def create
    @passt_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--add-passthrough', @passt_args], nil)
  end

  def destroy
    @passt_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--remove-passthrough', @passt_args], nil)
  end

  def generate_raw
    passt = []
    passt << [
      @resource[:inet_protocol],
      parse_args(@resource[:args]),
    ]
    passt.flatten
  end
end
