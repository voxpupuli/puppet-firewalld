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
#      puppet_d_rules << "#{fwdr[:inet_protocol]} #{fwdr[:table]} #{fwdr[:chain]} #{fwdr[:priority]} #{fwdr[:args]}"
      puppet_d_rules << fwdr.provider.build_direct_rule.join(' ')
      #self.debug("purge_direct_rules: #{puppet_d_rules}")
    end
    provider.get_direct_rules.reject { |p| puppet_d_rules.include?(p) }.each do |purge|
      self.debug("purge_direct_rules: should purge direct rule #{purge}")
      purge_d_rules << Puppet::Type.type(:firewalld_direct_rule).new(
        #:name          => self[:name],
        :name          => "#{self[:name]}-#{purge}",
        :inet_protocol => purge,
        :table         => purge,
        :chain         => purge,
        :priority      => purge,
        :args          => purge,
        :ensure        => :absent
      )
    end
    return purge_d_rules
  end

end
