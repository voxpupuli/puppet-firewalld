require 'puppet'

Puppet::Type.newtype(:firewalld_custom_service) do
  desc <<-DOC
  @summary Creates a custom firewalld service.


  You will still need to create a `firewalld_service` resource to bind your new
  service to a zone.

  @example Creating a custom 'test' service
    firewalld_custom_service {'test':
        ensure  => present,
        ports   => [{'port' => '1234', 'protocol' => 'tcp'}]
    }
  DOC

  ensurable do
    defaultvalues
    defaultto(:present)
  end

  newparam(:name, namevar: :true) do
    desc 'The target filename of the resource (without the .xml suffix)'

    newvalues(%r{.+})

    munge do |value|
      value.gsub(%r{[^\w-]}, '_')
    end
  end

  newproperty(:short) do
    desc 'The short description of the service'

    newvalues(%r{.+})
  end

  newproperty(:description) do
    desc 'The long description of the service'

    newvalues(%r{.+})
  end

  newproperty(:ports, array_matching: :all) do
    desc 'An Array of allowed port/protocol Hashes or Strings of the form `port/protocol`'

    defaultto(:unset)

    munge do |value|
      return value if value == :unset

      if value.is_a?(Hash)
        # Handle the legacy format from the module translate : to -
        value = Hash[value.map { |k, v| [k, v.to_s.tr(':', '-')] }]
      else
        port, protocol = value.split('/')

        # Just a protocol is valid
        if port && !protocol
          value = { 'protocol' => port }
        else
          port = port.to_s

          # Handle the legacy format from the module
          port.tr!(':', '-')

          value = { 'port' => port, 'protocol' => protocol }
        end
      end

      value
    end

    validate do |value|
      return if value == :unset

      value = munge(value)

      if value.is_a?(Hash)
        raise Puppet::ParseError, 'You must specify a protocol' unless value['protocol']

        if value['port']
          test_value = value['port'].to_s

          port_regexp = Regexp.new('^\d+(-\d+)?$')
          raise Puppet::ParseError, "Ports must match #{port_regexp}" unless port_regexp.match?(test_value)

          invalid_ports = test_value.split('-').reject { |x| x.to_i.between?(1, 65_535) }
          raise Puppet::ParseError, %(Ports must be between 1-65535 instead of '#{invalid_ports.join("' ,'")}') unless invalid_ports.empty?
        end

        allowed_protocols = %w[tcp udp sctp dccp]
        unless allowed_protocols.include?(value['protocol'])
          raise Puppet::ParseError, "The protocol must be one of '#{allowed_protocols.join(', ')}'. Got '#{value['protocol']}'"
        end
      end
    end

    def insync?(is)
      return true if Array(should).include?(:unset) && Array(is).empty?
      return false if Array(should).include?(:unset) && !Array(is).empty?

      is.reject { |x| x['port'].nil? }.sort_by { |x| x['port'] } ==
        should.reject { |x| x['port'].nil? }.sort_by { |x| x['port'] }
    end
  end

  newproperty(:protocols, array_matching: :all) do
    desc 'Protocols allowed by the service as defined in /etc/protocols'

    newvalues(%r{^[^\s#]+$})

    defaultto(:unset)

    def insync?(is)
      return true if Array(should).include?(:unset) && Array(is).empty?
      return false if Array(should).include?(:unset) && !Array(is).empty?

      protocols = Array(should)

      unless Array(@resource[:ports]).include?(:unset)
        protocols = (
          Array(should) +
          @resource[:ports].select { |x| x['port'].nil? }.map { |x| x['protocol'] }
        ).uniq
      end

      protocols.sort == Array(is).sort
    end
  end

  newproperty(:modules, array_matching: :all) do
    desc 'The list of netfilter modules to add to the service'

    newvalues(%r{^[\w-]+$})

    defaultto(:unset)

    munge do |value|
      return value if value == :unset

      value.split('nf_conntrack_').last
    end

    def insync?(is)
      return true if Array(should).include?(:unset) && Array(is).empty?
      return false if Array(should).include?(:unset) && !Array(is).empty?

      Array(is).sort == Array(should).sort
    end
  end

  newproperty(:ipv4_destination) do
    desc 'The IPv4 destination network of the service'

    defaultto(:unset)

    validate do |value|
      return if value == :unset

      require 'ipaddr'

      begin
        addr = IPAddr.new(value)

        raise Puppet::ParseError, "#{value} is not an IPv4 address" unless addr.ipv4?
      rescue => e
        raise Puppet::ParseError, e.to_s
      end
    end

    def insync?(is)
      return true if should == :unset && is.empty?
      is == should
    end
  end

  newproperty(:ipv6_destination) do
    desc 'The IPv6 destination network of the service'

    defaultto(:unset)

    validate do |value|
      return if value == :unset

      require 'ipaddr'

      begin
        addr = IPAddr.new(value)

        raise Puppet::ParseError, "#{value} is not an IPv6 address" unless addr.ipv6?
      rescue => e
        raise Puppet::ParseError, e.to_s
      end
    end

    def insync?(is)
      return true if should == :unset && is.empty?
      is == should
    end
  end

  autorequire(:service) do
    ['firewalld']
  end
end
