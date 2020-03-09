require 'puppet'
require 'puppet/parameter/boolean'

Puppet::Type.newtype(:firewalld_zone) do
  # Reference the types here so we know they are loaded
  #
  Puppet::Type.type(:firewalld_rich_rule)
  Puppet::Type.type(:firewalld_service)
  Puppet::Type.type(:firewalld_port)

  desc <<-DOC
    @summary
      Creates and manages firewalld zones.

    Creates and manages firewalld zones.

    Note that setting `ensure => 'absent'` to the built in firewalld zones will
    not work, and will generate an error. This is a limitation of firewalld itself, not the module.

    @example Create a zone called `restricted`
      firewalld_zone { 'restricted':
        ensure           => present,
        target           => '%%REJECT%%',
        interfaces       => [],
        sources          => [],
        purge_rich_rules => true,
        purge_services   => true,
        purge_ports      => true,
        icmp_blocks      => 'router-advertisement'
      }
  DOC

  ensurable do
    defaultvalues
    defaultto :present
  end

  # When set to 1 these variables cause the purge_* options to indicate to Puppet
  # that we are in a changed state
  #
  attr_reader :rich_rules_purgable
  attr_reader :services_purgable
  attr_reader :ports_purgable

  def generate
    return [] unless Puppet::Provider::Firewalld.available?
    purge_rich_rules if self[:purge_rich_rules] == :true
    purge_services if self[:purge_services] == :true
    purge_ports if self[:purge_ports] == :true
    []
  end

  newparam(:name) do
    desc 'Name of the rule resource in Puppet'
    isnamevar
  end

  newparam(:zone) do
    desc 'Name of the zone'
  end

  newparam(:description) do
    desc 'Description of the zone to add'
  end

  newparam(:short) do
    desc 'Short description of the zone to add'
  end

  newproperty(:target) do
    desc 'Specify the target for the zone'
  end

  newproperty(:interfaces, array_matching: :all) do
    desc 'Specify the interfaces for the zone'

    def insync?(is)
      case should
      when String then should.lines.sort == is.sort
      when Array then should.sort == is.sort
      else raise Puppet::Error, 'parameter interfaces must be a string or array of strings!'
      end
    end
  end

  newproperty(:masquerade) do
    desc 'Can be set to true or false, specifies whether to add or remove masquerading from the zone'
    newvalue(:true)
    newvalue(:false)
  end

  newproperty(:sources, array_matching: :all) do
    desc 'Specify the sources for the zone'

    def insync?(is)
      case should
      when String then should.lines.sort == is.sort
      when Array then should.sort == is.sort
      else raise Puppet::Error, 'parameter sources must be a string or array of strings!'
      end
    end

    def is_to_s(value = []) # rubocop:disable Style/PredicateName
      '[' + value.join(', ') + ']'
    end

    def should_to_s(value = [])
      '[' + value.join(', ') + ']'
    end
  end

  newproperty(:icmp_blocks, array_matching: :all) do
    desc "Specify the icmp-blocks for the zone. Can be a single string specifying one icmp type,
          or an array of strings specifying multiple icmp types. Any blocks not specified here will be removed
         "
    def insync?(is)
      case should
      when String then should.lines.sort == is.sort
      when Array then should.sort == is.sort
      else raise Puppet::Error, 'parameter icmp_blocks must be a string or array of strings!'
      end
    end
  end

  newproperty(:purge_rich_rules) do
    desc "When set to true any rich_rules associated with this zone
          that are not managed by Puppet will be removed.
         "
    newvalue(:false)
    newvalue(:true) do
      true
    end

    def retrieve
      return :false if @resource[:purge_rich_rules] == :false
      provider.resource.rich_rules_purgable ? :purgable : :true
    end
  end

  newproperty(:purge_services) do
    desc "When set to true any services associated with this zone
          that are not managed by Puppet will be removed.
         "
    newvalue(:false)
    newvalue(:true) do
      true
    end

    def retrieve
      return :false if @resource[:purge_services] == :false
      provider.resource.services_purgable ? :purgable : :true
    end
  end

  newproperty(:purge_ports) do
    desc "When set to true any ports associated with this zone
          that are not managed by Puppet will be removed."
    newvalue :false
    newvalue(:true) do
      true
    end

    def retrieve
      return :false if @resource[:purge_ports] == :false
      provider.resource.ports_purgable ? :purgable : :true
    end
  end

  validate do
    [:zone, :name].each do |attr|
      if self[attr] && (self[attr]).to_s.length > 17
        raise(Puppet::Error, "Zone identifier '#{attr}' must be less than 18 characters long")
      end
    end
  end

  autorequire(:service) do
    ['firewalld']
  end

  def purge_resource(res_type)
    if Puppet.settings[:noop] || self[:noop]
      Puppet.debug "Would have purged #{res_type.ref}, (noop)"
    else
      Puppet.debug "Purging #{res_type.ref}"
      res_type.provider.destroy if res_type.provider.exists?
    end
  end

  def purge_rich_rules
    return [] unless provider.exists?
    puppet_rules = []
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_rich_rule) }.each do |fwr|
      debug("not purging puppet controlled rich rule #{fwr[:name]}")
      puppet_rules << fwr.provider.build_rich_rule
    end
    provider.get_rules.reject { |p| puppet_rules.include?(p) }.each do |purge|
      debug("should purge rich rule #{purge}")
      res_type = Puppet::Type.type(:firewalld_rich_rule).new(
        name: purge,
        raw_rule: purge,
        ensure: :absent,
        zone: self[:name]
      )

      # If the rule exists in --permanent then we should purge it
      #
      purge_resource(res_type)

      # Even if it doesn't exist, it may be a running rule, so we
      # flag purge_rich_rules as changed so Puppet will reload
      # the firewall and drop orphaned running rules
      #
      @rich_rules_purgable = true
    end
  end

  def purge_services
    return [] unless provider.exists?
    puppet_services = []
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_service) }.each do |fws|
      if fws[:zone] == self[:name]
        debug("not purging puppet controlled service #{fws[:service]}")
        puppet_services << (fws[:service]).to_s
      end
    end
    provider.get_services.reject { |p| puppet_services.include?(p) }.each do |purge|
      debug("should purge service #{purge}")
      res_type = Puppet::Type.type(:firewalld_service).new(
        name: "#{self[:name]}-#{purge}",
        ensure: :absent,
        service: purge,
        zone: self[:name]
      )

      purge_resource(res_type)
      @services_purgable = true
    end
  end

  def purge_ports
    return [] unless provider.exists?
    puppet_ports = []
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_port) }.each do |fwp|
      if fwp[:zone] == self[:name]
        debug("Not purging puppet controlled port #{fwp[:port]}")
        puppet_ports << { 'port' => fwp[:port], 'protocol' => fwp[:protocol] }
      end
    end
    provider.get_ports.reject { |p| puppet_ports.include?(p) }.each do |purge|
      debug("Should purge port #{purge['port']} proto #{purge['protocol']}")
      res_type = Puppet::Type.type(:firewalld_port).new(
        name: "#{self[:name]}-#{purge['port']}-#{purge['protocol']}-purge",
        port: purge['port'],
        ensure: :absent,
        protocol: purge['protocol'],
        zone: self[:name]
      )
      purge_resource(res_type)
      @ports_purgable = true
    end
  end
end
