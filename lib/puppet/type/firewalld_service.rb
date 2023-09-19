# frozen_string_literal: true

require 'puppet'

Puppet::Type.newtype(:firewalld_service) do
  desc <<-DOC
  @summary
    Assigns a service to a specific firewalld zone.

  Assigns a service to a specific firewalld zone.

  `firewalld_service` will autorequire the `firewalld_zone` specified
  in the `zone` parameter or the `firewalld_policy` specified in the
  `policy` parameter and the `firewalld::custom_service` specified in
  the `service` parameter. There is no need to manually add
  dependencies for this.

  @example Allowing SSH
    firewalld_service {'Allow SSH in the public Zone':
        ensure  => present,
        zone    => 'public',
        service => 'ssh',
    }
  DOC

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

  newparam(:name, namevar: :true) do
    desc 'Name of the service resource in Puppet'
  end

  newparam(:service) do
    desc 'Name of the service to add'
    defaultto { @resource[:name] }
  end

  newparam(:zone) do
    desc 'Name of the zone to which you want to add the service, exactly one of zone and policy must be supplied'

    defaultto(:unset)
  end

  newparam(:policy) do
    desc 'Name of the policy to which you want to add the service, exactly one of zone and policy must be supplied'

    defaultto(:unset)
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

  autorequire(:firewalld_custom_service) do
    self[:service]&.gsub(%r{[^\w-]}, '_')
  end
end
