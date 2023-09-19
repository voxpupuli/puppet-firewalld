# frozen_string_literal: true

require 'puppet'
require 'puppet/parameter/boolean'

Puppet::Type.newtype(:firewalld_policy) do
  # Reference the types here so we know they are loaded
  #
  Puppet::Type.type(:firewalld_rich_rule)
  Puppet::Type.type(:firewalld_service)
  Puppet::Type.type(:firewalld_port)

  desc <<-DOC
    @summary
      Creates and manages firewalld policies.

    Creates and manages firewalld policies.

    Note that setting `ensure => 'absent'` to the built in firewalld
    policies will not work, and will generate an error. This is a
    limitation of firewalld itself, not the module.

    @example Create a policy called `anytorestricted`
      firewalld_policy { 'anytorestricted':
        ensure           => present,
        target           => '%%REJECT%%',
        ingress_zones    => ['ANY'],
        egress_zones     => ['restricted'],
        purge_rich_rules => true,
        purge_services   => true,
        purge_ports      => true,
        icmp_blocks      => 'router-advertisement'
      }
  DOC

  ensurable do
    desc 'Manage the state of this type.'
    defaultvalues
    defaultto :present
  end

  # When set to 1 these variables cause the purge_* options to
  # indicate to Puppet that we are in a changed state
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

  newparam(:policy) do
    desc 'Name of the policy'
  end

  newparam(:description) do
    desc 'Description of the policy to add'
  end

  newparam(:short) do
    desc 'Short description of the policy to add'
  end

  newproperty(:target) do
    desc 'Specify the target for the policy'
  end

  newproperty(:ingress_zones, array_matching: :all) do
    desc 'Specify the ingress zones for the policy as an array of strings'

    # Validation is done in the types validate below as the propertys
    # validate will never see all of values, only one element of it at
    # a time.

    def insync?(is)
      case should
      when Array then should.sort == is.sort
      when :unset then is.sort == []
      else raise Puppet::Error, "parameter #{self.class.name} must be an array of strings!"
      end
    end
  end

  newproperty(:egress_zones, array_matching: :all) do
    desc 'Specify the egress zones for the policy as an array of strings'

    # Validation is done in the types validate below as the propertys
    # validate will never see all of values, only one element of it at
    # a time.

    def insync?(is)
      case should
      when Array then should.sort == is.sort
      when :unset then is.sort == []
      else raise Puppet::Error, "parameter #{self.class.name} must be an array of strings!"
      end
    end
  end

  newproperty(:priority) do
    desc 'The priority of the policy as an integer (default -1)'

    defaultto('-1')

    munge do |value|
      case value
      when Numeric then value.to_s
      else value
      end
    end

    validate do |value|
      begin
        Integer(value)
      rescue StandardError
        raise Puppet::Error, 'parameter priority must be a non zero integer'
      end

      raise Puppet::Error, 'parameter priority must be non zero' if Integer(value).zero?
    end
  end

  newproperty(:masquerade) do
    desc 'Can be set to true or false, specifies whether to add or remove masquerading from the policy'
    newvalue(:true)
    newvalue(:false)
  end

  newproperty(:icmp_blocks, array_matching: :all) do
    desc "Specify the icmp-blocks for the policy. Can be a single string specifying one icmp type,
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
    desc "When set to true any rich_rules associated with this policy
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
    desc "When set to true any services associated with this policy
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
    desc "When set to true any ports associated with this policy
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

  def validate_zone_list(attr)
    if (self[:ensure] == :absent) && self[attr].is_a?(NilClass)
      self[attr] = []
      return
    end

    raise Puppet::Error, "parameter #{attr} must be an array of strings!" unless self[attr].is_a?(Array)

    raise Puppet::Error, "parameter #{attr} must contain at least one zone!" if self[attr].empty?

    self[attr].each do |element|
      case element
      when String then nil
      else raise Puppet::Error, "parameter #{attr} must be an array of strings!"
      end
    end

    return if self[attr].length == 1

    raise Puppet::Error, "parameter #{attr} must contain a single symbolic zone or one or more regular zones" if self[attr].include?('HOST') || self[attr].include?('ANY')
  end

  validate do
    %i[policy name].each do |attr|
      raise(Puppet::Error, "Policy identifier '#{attr}' must be less than 18 characters long") if self[attr] && (self[attr]).to_s.length > 17
    end
    validate_zone_list(:ingress_zones)
    validate_zone_list(:egress_zones)
  end

  autorequire(:service) do
    ['firewalld']
  end

  autorequire(:firewalld_zone) do
    (self[:ingress_zones] == :unset ? [] : self[:ingress_zones]) + (self[:egress_zones] == :unset ? [] : self[:egress_zones])
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
      if fwr[:policy] == self[:name]
        debug("not purging puppet controlled rich rule #{fwr[:name]}")
        puppet_rules << fwr.provider.build_rich_rule
      end
    end
    provider.get_rules.reject { |p| puppet_rules.include?(p) }.each do |purge|
      debug("should purge rich rule #{purge}")
      res_type = Puppet::Type.type(:firewalld_rich_rule).new(
        name: purge,
        raw_rule: purge,
        ensure: :absent,
        policy: self[:name]
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
      if fws[:policy] == self[:name]
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
        policy: self[:name]
      )

      purge_resource(res_type)
      @services_purgable = true
    end
  end

  def purge_ports
    return [] unless provider.exists?

    puppet_ports = []
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_port) }.each do |fwp|
      if fwp[:policy] == self[:name]
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
        policy: self[:name]
      )
      purge_resource(res_type)
      @ports_purgable = true
    end
  end
end
