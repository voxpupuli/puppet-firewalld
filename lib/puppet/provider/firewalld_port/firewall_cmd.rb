# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_port).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  mk_resource_methods

  def exists?
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
