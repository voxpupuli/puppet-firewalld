require 'puppet'

Puppet::Type.newtype(:firewalld_service) do
  desc <<-DOC
  @summary
    Assigns a service to a specific firewalld zone.

  Assigns a service to a specific firewalld zone.

  `firewalld_service` will autorequire the `firewalld_zone` specified in the
  `zone` parameter and the `firewalld::custom_service` specified in the `service`
  parameter. There is no need to manually add dependencies for this.

  @example Allowing SSH
    firewalld_service {'Allow SSH in the public Zone':
        ensure  => present,
        zone    => 'public',
        service => 'ssh',
    }
  DOC

  ensurable do
    newvalue(:present) do
      @resource.provider.create
    end

    newvalue(:absent) do
      @resource.provider.destroy
    end

    defaultto(:present)
  end

  newparam(:name, namevar: :true) do
    desc 'Name of the service resource in Puppet'
  end

  newparam(:service) do
    desc 'Name of the service to add'
    defaultto { @resource[:name] }
  end

  newparam(:zone) do
    desc 'Name of the zone to which you want to add the service'
  end

  autorequire(:firewalld_zone) do
    self[:zone]
  end

  autorequire(:service) do
    ['firewalld']
  end

  autorequire(:firewalld_custom_service) do
    self[:service].gsub(%r{[^\w-]}, '_') if self[:service]
  end
end
