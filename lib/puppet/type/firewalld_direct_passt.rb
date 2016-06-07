require 'puppet'

Puppet::Type.newtype(:firewalld_direct_passt) do

  @doc =%q{Allow to create a custom passthrough traffic in iptables/ip6tables/ebtables using firewalld direct interface.

    Example:

        firewalld_direct_pass {'Forward traffic from OUTPUT to OUTPUT_filter':
            ensure        => 'present',
            inet_protocol => 'ipv4',
            args          => '-A OUTPUT -j OUTPUT_filter',
        }

  }

  ensurable

  newparam(:name, :namevar => :true) do
    desc "Name of the passthrough resource in Puppet"
  end

  newparam(:inet_protocol) do
    desc "Name of the TCP/IP protocol to use (e.g: ipv4, ipv6)"
  end

  newparam(:args) do
    desc "Name of the passthrough to add (e.g: -A OUTPUT -j OUTPUT_filter)"
  end

end
