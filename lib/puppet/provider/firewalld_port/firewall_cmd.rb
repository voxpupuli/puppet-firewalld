require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_port).provide(
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
    @rule_args ||= build_port_rule
    @in_perm = execute_firewall_cmd(['--query-port', @rule_args], @resource[:zone], true, false).exitstatus.zero?
    @in_run = execute_firewall_cmd(['--query-port', @rule_args], @resource[:zone], false, false).exitstatus.zero?
    if @resource[:ensure] == :present
      @in_perm && @in_run
    else
      @in_perm || @in_run
    end
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
    execute_firewall_cmd(['--add-port', build_port_rule]) unless @in_perm
  end

  def destroy
    execute_firewall_cmd(['--remove-port', build_port_rule]) if @in_perm
  end
end
