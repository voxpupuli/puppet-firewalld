require 'puppet'
require 'puppet/parameter/boolean'
require File.dirname(__FILE__).concat('/firewalld_direct_rule.rb')
require File.dirname(__FILE__).concat('/firewalld_direct_chain.rb')
require File.dirname(__FILE__).concat('/firewalld_direct_passt.rb')

Puppet::Type.newtype(:firewalld_direct_purge) do

  @doc =%q{Allow to purge direct rules in iptables/ip6tables/ebtables using firewalld direct interface.

    Example:

        firewalld_direct_purge {'Purge all direct rules':
            purge_direct_rules  => true,
            purge_direct_chains => true,
            purge_direct_passt  => true
        }

  }

  ensurable

  def generate
    resources = Array.new

    if self.purge_direct_rules?
      resources.concat(purge_direct_rules())
    end
    if self.purge_direct_chains?
      resources.concat(purge_direct_chains())
    end
    if self.purge_direct_passt?
      resources.concat(purge_direct_passt())
    end

   return resources
  end

  newparam(:name, :namevar => true) do
    desc "Name of the resource in Puppet"
  end

  newparam(:purge_direct_rules, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "When set to true any direct rules that are not managed
          by Puppet will be removed."
    defaultto :false
  end

  newparam(:purge_direct_chains, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "When set to true any direct chains that are not managed
          by Puppet will be removed."
    defaultto :false
  end

  newparam(:purge_direct_passt, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "When set to true any direct passthrough that are not
          manage by Puppet will be removed."
    defaultto :false
  end

  def purge_direct_rules
    return Array.new unless provider.exists?
    purge_d_rules = Array.new
    puppet_d_rules = Array.new
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_direct_rule) }.each do |fwdr|
      puppet_d_rules << fwdr.provider.build_direct_rule.join(' ')
    end
    provider.get_direct_rules.reject { |p| puppet_d_rules.include?(p) }.each do |purge|
      self.debug("purge_direct_rules: should purge direct rule #{purge}")
      args=['--permanent', '--direct', '--remove-rule', "#{purge}"].join(' ')
      %x{ /usr/bin/firewall-cmd #{args} 2>&1}
      %x{ /usr/bin/firewall-cmd --reload 2>&1}
    end
    purge_d_rules
  end

  def purge_direct_chains
    return Array.new unless provider.exists?
    purge_d_chains = Array.new
    puppet_d_chains = Array.new
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_direct_chain) }.each do |fwdr|
      puppet_d_chains << fwdr.provider.build_direct_chain.join(' ')
    end
    provider.get_direct_chains.reject { |p| puppet_d_chains.include?(p) }.each do |purge|
      self.debug("purge_direct_chains: should purge direct chain #{purge}")
      args=['--permanent', '--direct', '--remove-chain', "#{purge}"].join(' ')
      %x{ /usr/bin/firewall-cmd #{args} 2>&1}
      %x{ /usr/bin/firewall-cmd --reload 2>&1}
    end
    purge_d_chains
  end

  def purge_direct_passt
    return Array.new unless provider.exists?
    purge_d_passt = Array.new
    puppet_d_passt = Array.new
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_direct_passt) }.each do |fwdr|
      puppet_d_passt << fwdr.provider.build_direct_passt.join(' ')
    end
    provider.get_direct_passt.reject { |p| puppet_d_passt.include?(p) }.each do |purge|
      self.debug("purge_direct_passt: should purge direct passthrough #{purge}")
      args=['--permanent', '--direct', '--remove-passthrough', "#{purge}"].join(' ')
      %x{ /usr/bin/firewall-cmd #{args} 2>&1}
      %x{ /usr/bin/firewall-cmd --reload 2>&1}
    end
    purge_d_passt
  end

end
