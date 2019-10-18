require 'puppet'

Puppet::Type.newtype(:firewalld_port) do
  @doc = "Assigns a port to a specific firewalld zone.
    firewalld_port will autorequire the firewalld_zone specified in the zone parameter so there is no need to add dependencies for this

    Example:

        firewalld_port {'Open port 8080 in the public Zone':
            ensure   => 'present',
            zone     => 'public',
            port     => 8080,
            protocol => 'tcp',
        }
  "

  ensurable do
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
    desc 'Name of the zone to which you want to add the port'
  end

  newparam(:port) do
    desc 'Specify the element as a port'
    defaultto { @resource[:name] }
    munge(&:to_s)
  end

  newparam(:protocol) do
    desc 'Specify the element as a protocol'
  end

  autorequire(:firewalld_zone) do
    self[:zone]
  end

  autorequire(:service) do
    ['firewalld']
  end
end
