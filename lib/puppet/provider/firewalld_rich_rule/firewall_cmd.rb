require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_rich_rule).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  attr_accessor :in_perm, :in_run

  mk_resource_methods

  def initialize(value = {})
    super(value)
    @in_perm = false
    @in_run = false
  end

  def exists?
    @rule_args ||= build_rich_rule
    @in_perm = execute_firewall_cmd(['--query-rich-rule', @rule_args], @resource[:zone], true, false).exitstatus.zero?
    @in_run = execute_firewall_cmd(['--query-rich-rule', @rule_args], @resource[:zone], false, false).exitstatus.zero?
    if @resource[:ensure] == :present
      @in_perm && @in_run
    else
      @in_perm || @in_run
    end
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
    [:service, :port, :protocol, :icmp_block, :icmp_type, :masquerade, :forward_port]
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
    if @resource[:audit].is_a?(Hash)
      args << quote_keyval('limit value', @resource[:log]['limit'])
    end
    args
  end

  def eval_action
    return [] unless (action = @resource[:action])
    args = []
    if action.is_a?(Hash)
      args << action[:action]
      args << quote_keyval('type', action[:type])
    else
      args << action
    end
  end

  def build_rich_rule
    return @resource[:raw_rule] if @resource[:raw_rule]
    rule = ['rule']
    rule << [
      key_val_opt('family'),
      eval_priority,
      eval_source,
      eval_dest,
      eval_element,
      eval_log,
      eval_audit,
      eval_action
    ]
    @resource[:raw_rule] = raw_rule = rule.flatten.reject(&:empty?).join(' ')
    raw_rule
  end

  def create
    execute_firewall_cmd(['--add-rich-rule', build_rich_rule]) unless @in_perm
  end

  def destroy
    execute_firewall_cmd(['--remove-rich-rule', build_rich_rule]) if @in_perm
  end
end
