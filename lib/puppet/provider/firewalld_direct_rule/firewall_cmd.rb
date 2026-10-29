# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_direct_rule).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  # Lists every configured direct rule with a single firewall-cmd
  # invocation. See Puppet::Provider::Firewalld.parse_all_rules.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.all_rules
    parse_all_rules(execute_firewall_cmd(['--direct', '--get-all-rules'], nil))
  end

  def self.instances
    all_rules.map do |r|
      new(
        ensure: :present,
        name: "#{r['inet_protocol']}-#{r['table']}-#{r['chain']}-#{r['priority']}-#{r['args'].join(' ')}",
        inet_protocol: r['inet_protocol'],
        table: r['table'],
        chain: r['chain'],
        priority: r['priority'],
        args: r['args'].join(' '),
      )
    end
  end

  # Resources are keyed by an arbitrary Puppet title, so we can't match
  # discovered instances back to resources by name (see self.instances).
  # Instead each declared resource's args are tokenized the same way
  # generate_raw does, and matched directly against the rules gathered
  # above.
  #
  def self.prefetch(resources)
    rules = all_rules

    resources.each_value do |resource|
      provider = resource.provider
      args = provider.parse_args(resource[:args]).map { |a| a.delete("'") }
      present = rules.any? do |r|
        r['inet_protocol'] == resource[:inet_protocol] &&
          r['table'] == resource[:table] &&
          r['chain'] == resource[:chain] &&
          r['priority'] == resource[:priority].to_s &&
          r['args'] == args
      end
      resource.provider = new(
        ensure: present ? :present : :absent,
        name: resource[:name],
        inet_protocol: resource[:inet_protocol],
        table: resource[:table],
        chain: resource[:chain],
        priority: resource[:priority],
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

    @rule_args ||= generate_raw
    output = execute_firewall_cmd(['--direct', '--query-rule', @rule_args], nil, true, false)
    output.include?('yes')
  end

  def create
    @rule_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--add-rule', @rule_args], nil)
  end

  def destroy
    @rule_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--remove-rule', @rule_args], nil)
  end

  def generate_raw
    rule = []
    rule << [
      @resource[:inet_protocol],
      @resource[:table],
      @resource[:chain],
      @resource[:priority].to_s,
      parse_args(@resource[:args]),
    ]
    rule.flatten
  end
end
