require 'puppet'

Puppet::Type.newtype(:firewalld_direct_chain) do
  @doc = "Allow to create a custom chain in iptables/ip6tables/ebtables using firewalld direct interface.

    Example:

        firewalld_direct_chain {'Add custom chain LOG_DROPS':
            name           => 'LOG_DROPS',
            ensure         => 'present',
            inet_protocol  => 'ipv4',
            table          => 'filter'
        }

  "

  ensurable do
    defaultvalues
    defaultto :present
  end

  def self.title_patterns
    [
      [
        %r{^([^:]+):([^:]+):([^:]+)$},
        [[:inet_protocol], [:table], [:name]]
      ],
      [
        %r{^([^:]+)$},
        [[:name]]
      ]
    ]
  end

  newparam(:name, namevar: :true) do
    desc 'Name of the chain eg: LOG_DROPS'
  end

  newparam(:inet_protocol) do
    desc 'Name of the TCP/IP protocol to use (e.g: ipv4, ipv6)'
    newvalues('ipv4', 'ipv6')
    defaultto('ipv4')
    munge(&:to_s)
    isnamevar
  end

  newparam(:table) do
    desc 'Name of the table type to add (e.g: filter, nat, mangle, raw)'
    isnamevar
  end

  autorequire(:service) do
    ['firewalld']
  end
end
