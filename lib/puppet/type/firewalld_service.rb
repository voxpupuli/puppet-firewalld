require 'puppet'

Puppet::Type.newtype(:firewalld_service) do

  @doc =%q{Assigns a service to a specific firewalld zone.
    firewalld_Service will autorequire the firewalld_zone specified in the zone parameter so there is no need to add dependancies for this
  
    Example:
        
        firewalld_service {'Allow SSH in the public Zone':
            ensure  => 'present',
            zone    => 'public',
            service => 'ssh',
        }
  
  }

  ensurable
  
  newparam(:name, :namevar => :true) do
    desc "Name of the service resource in Puppet"
  end
  
  newparam(:service) do
    desc "Name of the service to add"
  end
  
  newparam(:zone) do
    desc "Name of the zone to which you want to add the service"
  end
  
  autorequire(:firewalld_zone) do
    self[:zone]
  end

end
