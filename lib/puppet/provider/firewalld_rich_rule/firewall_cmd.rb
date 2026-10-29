# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_rich_rule).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  mk_resource_methods

  # Builds a Hash of zone/policy name => { 'rich_rules' => [...], ... } from
  # a single firewall-cmd invocation. See Puppet::Provider::Firewalld.parse_list_all.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.zone_rich_rule_map
    parse_list_all(execute_firewall_cmd(['--list-all-zones'], nil))
  end

  def self.policy_rich_rule_map
    parse_list_all(execute_firewall_cmd(['--list-all-policies'], nil))
  end

  def self.instances
    found = []
    zone_rich_rule_map.each do |zone, data|
      data['rich_rules'].each do |rule|
        found << new(ensure: :present, name: rule, raw_rule: rule, zone: zone, policy: :unset)
      end
    end
    policy_rich_rule_map.each do |policy, data|
      data['rich_rules'].each do |rule|
        found << new(ensure: :present, name: rule, raw_rule: rule, zone: :unset, policy: policy)
      end
    end
    found
  end

  # Resources are keyed by an arbitrary Puppet title, so we can't match
  # discovered instances back to resources by name (see self.instances).
  # Instead each declared resource's rule text is built and looked up
  # directly in the zone/policy maps gathered above. This relies on
  # build_rich_rule producing a string byte-for-byte identical to
  # firewalld's own canonical rich-rule serialization (field order:
  # priority, family, source, destination, element, log, audit, action).
  #
  def self.prefetch(resources)
    # Only fetch what's actually referenced, in case a catalog only uses
    # zones or only uses policies.
    zones = (resources.each_value.any? { |r| r[:zone] != :unset }) ? zone_rich_rule_map : {}
    policies = (resources.each_value.any? { |r| r[:policy] != :unset }) ? policy_rich_rule_map : {}

    resources.each_value do |resource|
      rule_str = resource.provider.build_rich_rule
      data = (resource[:zone] == :unset) ? policies[resource[:policy]] : zones[resource[:zone]]
      present = data ? data['rich_rules'].include?(rule_str) : false
      resource.provider = new(
        ensure: present ? :present : :absent,
        name: resource[:name],
        raw_rule: rule_str,
        zone: resource[:zone],
        policy: resource[:policy],
      )
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow (eg. the ad-hoc resources firewalld_zone's
  # purge_rich_rules constructs to check and remove unmanaged rules) have no
  # prefetched state, so fall back to a live query for those.
  def exists?
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

    @rule_args ||= build_rich_rule
    output = if @resource[:zone] == :unset
               execute_firewall_cmd_policy(['--query-rich-rule', @rule_args],
                                           @resource[:policy],
                                           true, false)
             else
               execute_firewall_cmd(['--query-rich-rule', @rule_args],
                                    @resource[:zone],
                                    true, false)
             end
    output.exitstatus.zero?
  end

  def quote_keyval(key, val)
    val ? "#{key}=\"#{val}\"" : ''
  end

  def key_val_opt(opt, resource_param = opt)
    quote_keyval(opt, @resource[resource_param.to_s])
  end

  def eval_priority
    return [] unless (priority = @resource[:priority])

    quote_keyval('priority', priority)
  end

  def eval_source
    args = []
    return [] unless (addr = @resource[:source])

    invert = addr['invert'] ? ' NOT' : ''
    args << "source#{invert}"
    args << quote_keyval('address', addr['address'])
    args << quote_keyval('ipset', addr['ipset'])
    args
  end

  def eval_dest
    args = []
    return [] unless (addr = @resource[:dest])

    invert = addr['invert'] ? ' NOT' : ''
    args << "destination#{invert}"
    args << quote_keyval('address', addr['address'])
    args << quote_keyval('ipset', addr['ipset'])
    args
  end

  def elements
    %i[service port protocol icmp_block icmp_type masquerade forward_port]
  end

  def eval_element
    args = []
    element = elements.select { |e| resource[e] }.first
    args << element.to_s.tr('_', '-')
    case element
    when :service
      args << quote_keyval('name', @resource[:service])
    when :port
      args << quote_keyval('port', @resource[:port]['port'])
      args << quote_keyval('protocol', @resource[:port]['protocol'])
    when :icmp_block
      args << quote_keyval('name', @resource[:icmp_block])
    when :icmp_type
      args << quote_keyval('name', @resource[:icmp_type])
    # when :masquerade
    #   `masquerade` doesn't accept any arguments.
    when :forward_port
      args << quote_keyval('port',     @resource[:forward_port]['port'])
      args << quote_keyval('protocol', @resource[:forward_port]['protocol'])
      args << quote_keyval('to-port',  @resource[:forward_port]['to_port'])
      args << quote_keyval('to-addr',  @resource[:forward_port]['to_addr'])
    when :protocol
      args << quote_keyval('value', @resource[:protocol])
    end
    args
  end

  def eval_log
    return [] unless @resource[:log]

    args = []
    args << 'log'
    if @resource[:log].is_a?(Hash)
      args << quote_keyval('prefix', @resource[:log]['prefix'])
      args << quote_keyval('level', @resource[:log]['level'])
      args << quote_keyval('limit value', @resource[:log]['limit'])
    end
    args
  end

  def eval_audit
    return [] unless @resource[:audit]

    args = []
    args << 'audit'
    args << quote_keyval('limit value', @resource[:log]['limit']) if @resource[:audit].is_a?(Hash)
    args
  end

  def eval_action
    return [] unless (action = @resource[:action])

    args = []
    if action.is_a?(Hash)
      args << action['action']
      args << quote_keyval('type', action['type'])
    else
      args << action
    end
  end

  def build_rich_rule
    return @resource[:raw_rule] if @resource[:raw_rule]

    # Field order must match firewalld's own canonical serialization (see
    # Rich_Rule.__str__ in firewalld's python sources: priority, family,
    # source, destination, element, log, audit, action) so that the string
    # this builds is byte-for-byte identical to what `--list-rich-rules`/
    # `--list-all-zones` report back. Resources with a priority set would
    # otherwise never raw-string-match firewalld's output, breaking
    # purge_rich_rules and any other exact-match comparison.
    rule = ['rule']
    rule << [
      eval_priority,
      key_val_opt('family'),
      eval_source,
      eval_dest,
      eval_element,
      eval_log,
      eval_audit,
      eval_action,
    ]
    @resource[:raw_rule] = raw_rule = rule.flatten.reject(&:empty?).join(' ')
    raw_rule
  end

  def create
    if @resource[:zone] == :unset
      execute_firewall_cmd_policy(['--add-rich-rule', build_rich_rule])
    else
      execute_firewall_cmd(['--add-rich-rule', build_rich_rule])
    end
  end

  def destroy
    if @resource[:zone] == :unset
      execute_firewall_cmd_policy(['--remove-rich-rule', build_rich_rule])
    else
      execute_firewall_cmd(['--remove-rich-rule', build_rich_rule])
    end
  end
end
