# frozen_string_literal: true

require 'puppet'

Puppet::Type.newtype(:firewalld_direct_passthrough) do
  @doc = "Allow to create a custom passthroughhrough traffic in iptables/ip6tables/ebtables using firewalld direct interface.

    Example:

        firewalld_direct_passthrough {'Forward traffic from OUTPUT to OUTPUT_filter':
            ensure        => 'present',
            inet_protocol => 'ipv4',
            args          => '-A OUTPUT -j OUTPUT_filter',
        }

    Or using namevar

        firewalld_direct_passthrough {'-A OUTPUT -j OUTPUT_filter':
            ensure        => 'present',
        }

  "

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:inet_protocol) do
    desc 'Name of the TCP/IP protocol to use (e.g: ipv4, ipv6)'
    newvalues('ipv4', 'ipv6')
    defaultto('ipv4')
    munge(&:to_s)
  end

  newparam(:args) do
    isnamevar
    desc 'Name of the passthroughhrough to add (e.g: -A OUTPUT -j OUTPUT_filter)'
  end

  autorequire(:service) do
    ['firewalld']
  end
end
