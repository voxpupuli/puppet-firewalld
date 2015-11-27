require 'puppet'
require 'puppet/parameter/boolean'
require File.dirname(__FILE__).concat('/firewalld_rich_rule.rb')
require File.dirname(__FILE__).concat('/firewalld_service.rb')
require File.dirname(__FILE__).concat('/firewalld_port.rb')

Puppet::Type.newtype(:firewalld_zone) do

  @doc =%q{Creates and manages firewald zones.
    Note that setting ensure => 'absent' to the built in firewalld zones will
    not work, and will generate an error. This is a limitation of firewalld itself, not the module.

    Example:

      firewalld_zone { 'restricted':
        ensure           => present,
        target           => '%%REJECT%%',
        sources          => [],
        purge_rich_rules => true,
        purge_services   => true,
        purge_ports      => true,
        icmp_blocks      => 'router-advertisement'
      }

  }

  ensurable
  

  def generate
  
    resources = Array.new
  
    if self.purge_rich_rules?
      resources.concat(purge_rich_rules())
    end
    if self.purge_services?
      resources.concat(purge_services())
    end
    if self.purge_ports?
      resources.concat(purge_ports())
    end
    
    return resources
    
  end


  newparam(:name) do
    desc "Name of the rule resource in Puppet"
  end

  newparam(:zone) do
    desc "Name of the zone"
  end

  newproperty(:target) do
    desc "Specify the target for the zone"
  end

  newproperty(:sources, :array_matching => :all) do
    desc "Specify the sources for the zone"

    def insync?(is)
      case should
      when String then should.lines.sort == is
      when Array then should.sort == is
      else raise Puppet::Error, "parameter sources must be a string or array of strings!"
      end
    end

    def is_to_s(value = [])
      '[' + value.join(", ") + ']'
    end

    def should_to_s(value = [])
      '[' + value.join(", ") + ']'
    end
  end

  newproperty(:icmp_blocks, :array_matching => :all) do
    desc "Specify the icmp-blocks for the zone. Can be a single string specifying one icmp type,
          or an array of strings specifying multiple icmp types. Any blocks not specified here will be removed
         "
    def insync?(is)
        case should
            when String then should.lines.sort == is
            when Array then should.sort == is
            else raise Puppet::Error, "parameter icmp_blocks must be a string or array of strings!"
        end
    end
  end

  newparam(:purge_rich_rules, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "When set to true any rich_rules associated with this zone
          that are not managed by Puppet will be removed.
         "
    defaultto :false
  end
  
  newparam(:purge_services, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "When set to true any services associated with this zone
          that are not managed by Puppet will be removed.
         "
    defaultto :false
  end
  
  newparam(:purge_ports, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "When set to true any ports associated with this zone
          that are not managed by Puppet will be removed."
    defaultto :false
  end

  def purge_rich_rules
    return Array.new unless provider.exists?
    purge_rules = Array.new
    puppet_rules = Array.new
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_rich_rule) }.each do |fwr|
      self.debug("not purging puppet controlled rich rule #{fwr[:name]}")
      puppet_rules << fwr.provider.build_rich_rule
    end
    provider.get_rules.reject { |p| puppet_rules.include?(p) }.each do |purge|
      self.debug("should purge rich rule #{purge}")
      purge_rules << Puppet::Type.type(:firewalld_rich_rule).new(
        :name     => purge,
        :raw_rule => purge,
        :ensure   => :absent,
        :zone     => self[:name]
      )
    end
    return purge_rules
  end
  
  def purge_services
    return Array.new unless provider.exists?
    purge_services = Array.new
    puppet_services = Array.new
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_service) }.each do |fws|
      if fws[:zone] == self[:name]        
        self.debug("not purging puppet controlled service #{fws[:service]}")
        puppet_services << "#{fws[:service]}"
      end
    end
    provider.get_services.reject { |p| puppet_services.include?(p) }.each do |purge|
      self.debug("should purge service #{purge}")
      purge_services << Puppet::Type.type(:firewalld_service).new(
        :name     => "#{self[:name]}-#{purge}",
        :ensure   => :absent,
        :service  => purge,
        :zone     => self[:name]
      )
    end
    return purge_services
  end

  def purge_ports
    return Array.new unless provider.exists?
    purge_ports = Array.new
    puppet_ports = Array.new
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_port) }.each do |fwp|
      if fwp[:zone] == self[:name]
        self.debug("Not purging puppet controlled port #{fwp[:port]}")
        puppet_ports << { "port" => fwp[:port], "protocol" => fwp[:protocol] }
      end
    end
    provider.get_ports.reject { |p| puppet_ports.include?(p) }.each do |purge|
      self.debug("Should purge port #{purge['port']} proto #{purge['protocol']}")
      purge_ports << Puppet::Type.type(:firewalld_port).new(
        :name     => "#{self[:name]}-#{purge['port']}-#{purge['protocol']}-purge",
        :port     => purge["port"],
        :ensure   => :absent,
        :port     => purge["port"],
        :protocol => purge["protocol"],
        :zone     => self[:name]
      )
    end
    return purge_ports
  end

end

