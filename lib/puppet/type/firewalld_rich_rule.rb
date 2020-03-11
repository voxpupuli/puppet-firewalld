Puppet::Type.newtype(:firewalld_rich_rule) do
  @doc = "Manages firewalld rich rules.

    firewalld_rich_rules will autorequire the firewalld_zone specified in the zone parameter so there is no need to add dependencies for this

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
    defaultvalues
    defaultto :present
  end

  newparam(:name) do
    isnamevar
    desc 'Name of the rule resource in Puppet'
  end

  newparam(:zone) do
    desc 'Name of the zone'
  end

  newparam(:family) do
    desc 'IP family, one of ipv4 or ipv6, defauts to ipv4'
    newvalues(:ipv4, :ipv6)
    defaultto :ipv4
    munge(&:to_s)
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
    def _validate_action(value)
      raise Puppet::Error, "Authorized action values are `accept`, `reject`, `drop` or `mark`, got #{value}" unless %w[accept drop reject mark].include? value
    end
    validate do |value|
      if value.is_a?(Hash)
        if value.keys.sort != [:action, :type]
          raise Puppet::Error, "Rule action hash should contain `action` and `type` keys. Use a string if you only want to declare the action to be `accept` or `reject`. Got #{value}"
        end
        _validate_action(value[:action])
      elsif value.is_a?(String)
        _validate_action(value)
      end
    end
  end

  newparam(:raw_rule) do
    desc "Manage the entire rule as one string - this is used internally by firwalld_zone to
          handle pruning of rules"
  end

  def elements
    [:service, :port, :protocol, :icmp_block, :icmp_type, :masquerade, :forward_port]
  end

  validate do
    errormsg = "Only one element (#{elements.join(',')}) may be specified."
    raise errormsg if elements.select { |e| self[e] }.size > 1
  end

  autorequire(:firewalld_zone) do
    self[:zone]
  end

  autorequire(:ipset) do
    self[:source]['ipset'] if self[:source].is_a?(Hash)
  end

  autorequire(:service) do
    ['firewalld']
  end
end
