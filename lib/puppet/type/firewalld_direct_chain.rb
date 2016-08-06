require 'puppet'

Puppet::Type.newtype(:firewalld_direct_chain) do

  @doc =%q{Allow to create a custom chain in iptables/ip6tables/ebtables using firewalld direct interface.

    Example:

        firewalld_direct_chain {'Add custom chain LOG_DROPS':
            ensure         => 'present',
            inet_protocol  => 'ipv4',
            table          => 'filter',
            custom_chain   => 'LOG_DROPS',
        }

  }

  ensurable

  newparam(:name, :namevar => :true) do
    desc "Name of the chain resource in Puppet"
  end

  newparam(:inet_protocol) do
    desc "Name of the TCP/IP protocol to use (e.g: ipv4, ipv6)"
  end

  newparam(:table) do
    desc "Name of the table type to add (e.g: filter, nat, mangle, raw)"
  end

  newparam(:custom_chain) do
    desc "Name of the chain type to add (e.g: LOG_DROPS)"
  end

end
