# frozen_string_literal: true

Puppet::Type.newtype(:firewalld_rich_rule) do
  @doc = "Manages firewalld rich rules.

    firewalld_rich_rules will autorequire the firewalld_zone specified
    in the zone parameter or the firewalld_policy specified in the
    policy parameter so there is no need to add dependencies for this

    Example:

      firewalld_rich_rule { 'Accept SSH from barny':
        ensure => present,
        zone   => 'restricted',
        source => '192.168.1.2/32',
        service => 'ssh',
        action  => 'accept',
      }

  "

  ensurable do
    desc 'Manage the state of this type.'
    defaultvalues
    defaultto :present
  end

  newparam(:name) do
    isnamevar
    desc 'Name of the rule resource in Puppet'
  end

  newparam(:zone) do
    desc 'Name of the zone to attach the rich rule to, exactly one of zone and policy must be supplied'

    defaultto(:unset)
  end

  newparam(:policy) do
    desc 'Name of the policy to attach the rich rule to, exactly one of zone and policy must be supplied'

    defaultto(:unset)
  end

  newparam(:family) do
    desc 'IP family, one of ipv4, ipv6 or eb, defauts to ipv4'
    newvalues(:ipv4, :ipv6, :eb)
    defaultto :ipv4
    munge(&:to_s)
  end

  newparam(:priority) do
    desc 'Rule priority, it can be in the range of -32768 to 32767'
    munge(&:to_s)

    validate do |value|
      raise Puppet::Error, 'Priority must be between -32768 and 32767' unless value.to_i.to_s == value.to_s && (-32_768..32_767).include?(value.to_i)
    end
  end

  newparam(:source) do
    desc 'Specify source address, this can be a string of the IP address or a hash containing other options'
    munge do |value|
      if value.is_a?(String)
        { 'address' => value }
      else
        errormsg = 'Only one source type address or ipset may be specified.'
        raise errormsg if value.key?('address') && value.key?('ipset')

        value
      end
    end
  end
  newparam(:dest) do
    desc 'Specify destination address, this can be a string of the IP address or a hash containing other options'
    munge do |value|
      if value.is_a?(String)
        { 'address' => value }
      else
        errormsg = 'Only one source type address or ipset may be specified.'
        raise errormsg if value.key?('address') && value.key?('ipset')

        value
      end
    end
  end

  newparam(:service) do
    desc 'Specify the element as a service'
  end

  newparam(:port) do
    desc 'Specify the element as a port'
  end

  newparam(:protocol) do
    desc 'Specify the element as a protocol'
  end

  newparam(:icmp_block) do
    desc 'Specify the element as an icmp-block'
  end

  newparam(:icmp_type) do
    desc 'Specify the element as an icmp-type'
  end

  newparam(:masquerade) do
    desc 'Specify the element as masquerade'
  end

  newparam(:forward_port) do
    desc 'Specify the element as forward-port'
  end

  newparam(:log) do
    desc 'doc'
  end

  newparam(:audit) do
    desc 'doc'
  end

  newparam(:action) do
    desc 'Specify the action fo this rule'
    def _validate_action(value)
      raise Puppet::Error, "Authorized action values are `accept`, `reject`, `drop` or `mark`, got #{value}" unless %w[accept drop reject mark].include? value
    end
    validate do |value|
      case value
      when Hash
        raise Puppet::Error, "Rule action hash should contain `action` and `type` keys. Use a string if you only want to declare the action to be `accept` or `reject`. Got #{value}" if value.keys.sort != %w[action type]

        _validate_action(value['action'])
      when String
        _validate_action(value)
      end
    end
  end

  newparam(:raw_rule) do
    desc "Manage the entire rule as one string - this is used
          internally by firwalld_zone and firewalld_policy to handle
          pruning of rules"
  end

  def elements
    %i[service port protocol icmp_block icmp_type masquerade forward_port]
  end

  validate do
    errormsg = "Only one element (#{elements.join(',')}) may be specified."
    raise errormsg if elements.select { |e| self[e] }.size > 1

    raise Puppet::Error, 'only one of the parameters zone and policy may be supplied' if self[:zone] != :unset && self[:policy] != :unset

    raise Puppet::Error, 'one of the parameters zone and policy must be supplied' if self[:zone] == :unset && self[:policy] == :unset
  end

  autorequire(:firewalld_zone) do
    self[:zone] if self[:zone] != :unset
  end

  autorequire(:firewalld_policy) do
    self[:policy] if self[:policy] != :unset
  end

  autorequire(:ipset) do
    self[:source]['ipset'] if self[:source].is_a?(Hash)
  end

  autorequire(:ipset) do
    self[:dest]['ipset'] if self[:dest].is_a?(Hash)
  end

  autorequire(:service) do
    ['firewalld']
  end
end
