require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_direct_rule).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  def initialize(value = {})
    super(value)
    @in_perm = false
    @in_run = false
  end

  def exists?
    @rule_args ||= generate_raw
    @in_perm = execute_firewall_cmd(['--direct', '--query-rule', @rule_args], nil, true, false).include?('yes')
    @in_run = execute_firewall_cmd(['--direct', '--query-rule', @rule_args], nil, false, false).include?('yes')
    if @resource[:ensure] == :present
      @in_perm && @in_run
    else
      @in_perm || @in_run
    end
  end

  def create
    @rule_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--add-rule', @rule_args], nil) unless @in_perm
  end

  def destroy
    @rule_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--remove-rule', @rule_args], nil) if @in_perm
  end

  def generate_raw
    rule = []
    rule << [
      @resource[:inet_protocol],
      @resource[:table],
      @resource[:chain],
      @resource[:priority].to_s,
      parse_args(@resource[:args])
    ]
    rule.flatten
  end
end
