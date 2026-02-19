# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld_dbus.rb')
require File.join(File.dirname(__dir__), '..', '..', 'puppet_x', 'firewalld', 'rich_rule.rb')

Puppet::Type.type(:firewalld_rich_rule).provide(
  :dbus,
  parent: Puppet::Provider::FirewalldDbus
) do
  desc 'Interact through DBus'

  mk_resource_methods

  def exists?
    if dbus_resource.name == 'org.fedoraproject.FirewallD1.config.policy'
      dbus_resource_settings['rich_rules'].include? build_rich_rule
    else
      dbus_resource.queryRichRule(build_rich_rule)
    end
  end

  def build_rich_rule
    @resource[:raw_rule] ||= PuppetX::Firewalld::RichRule.from_resource(@resource).rule
  end

  def create
    debug("Creating rich rule #{build_rich_rule}")
    if dbus_resource.name == 'org.fedoraproject.FirewallD1.config.policy'
      rules = dbus_resource_settings['rich_rules']
      rules << build_rich_rule
      dbus_update_resource_settings({ 'rich_rules' => rules })
    else
      dbus_resource.addRichRule(build_rich_rule)
    end
    reload_firewall
  end

  def destroy
    debug("Destroying rich rule #{build_rich_rule}")
    if dbus_resource.name == 'org.fedoraproject.FirewallD1.config.policy'
      rules = dbus_resource_settings['rich_rules']
      rules.delete build_rich_rule
      dbus_update_resource_settings({ 'rich_rules' => rules })
    else
      dbus_resource.removeRichRule(build_rich_rule)
    end
    reload_firewall
  end
end
