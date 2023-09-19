# frozen_string_literal: true

require 'puppet'

Puppet::Type.newtype(:firewalld_port) do
  @doc = "Assigns a port to a specific firewalld zone.

    firewalld_port will autorequire the firewalld_zone specified in
    the zone parameter or the firewalld_policy specified in the policy
    parameter so there is no need to add dependencies for this

    Example:

        firewalld_port {'Open port 8080 in the public Zone':
            ensure   => 'present',
            zone     => 'public',
            port     => 8080,
            protocol => 'tcp',
        }
  "

  ensurable do
    desc 'Manage the state of this type.'

    newvalue(:present) do
      @resource.provider.create
    end

    newvalue(:absent) do
      @resource.provider.destroy
    end

    defaultto(:present)
  end

  newparam(:name, namevar: true) do
    desc 'Name of the port resource in Puppet'
  end

  newparam(:zone) do
    desc 'Name of the zone to which you want to add the port, exactly one of zone and policy must be supplied'

    defaultto(:unset)
  end

  newparam(:policy) do
    desc 'Name of the policy to which you want to add the port, exactly one of zone and policy must be supplied'

    defaultto(:unset)
  end

  newparam(:port) do
    desc 'Specify the element as a port'
    defaultto { @resource[:name] }
    munge(&:to_s)
  end

  newparam(:protocol) do
    desc 'Specify the element as a protocol'
  end

  validate do
    raise Puppet::Error, 'only one of the parameters zone and policy may be supplied' if self[:zone] != :unset && self[:policy] != :unset

    raise Puppet::Error, 'one of the parameters zone and policy must be supplied' if self[:zone] == :unset && self[:policy] == :unset
  end

  autorequire(:firewalld_zone) do
    self[:zone] if self[:zone] != :unset
  end

  autorequire(:firewalld_policy) do
    self[:policy] if self[:policy] != :unset
  end

  autorequire(:service) do
    ['firewalld']
  end
end
