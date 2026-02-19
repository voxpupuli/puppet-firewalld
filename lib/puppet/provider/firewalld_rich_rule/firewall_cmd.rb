# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')
require File.join(File.dirname(__dir__), '..', '..', 'puppet_x', 'firewalld', 'rich_rule.rb')

Puppet::Type.type(:firewalld_rich_rule).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  mk_resource_methods

  def exists?
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

  def build_rich_rule
    PuppetX::Firewalld::RichRule.from_resource(@resource).rule
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
