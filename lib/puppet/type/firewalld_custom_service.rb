require 'puppet'

Puppet::Type.newtype(:firewalld_custom_service) do

   @doc =%q{Creates a custom service definition in firewalld. Firewalld will create a blank template for
     the service, to be replaced by the firewalld::custom_service defined type.
  
    Example:
    
        firewalld_custom_service {'MyService':}
  
  }

  ensurable

  newparam(:name, :namevar => :true) do
    desc "Name of the custom service resource in Puppet"
  end

# Left in in case we decide to handle the config file creation directly in ruby instead of the defined type
#  newparam(:short, :namevar => :true) do
#    defaultto :name
#    desc "Short name of the firewalld service (the one displayed on the command line output of various commands)"
#  end
#  
#  newparam(:description) do
#    desc "(Optional) A short description of the service"
#  end
#  
#  newparam(:port) do
#    desc "(Optional) An array of hashes, where each hash defines a protocol and/or port associated with this service. Each hash requires both port and protocol keys, even if the value is an empty string. Specifying a port only works for TCP & UDP, otherwise leave it empty and the entire protocol will be allowed"
#  end
#  
#  newparam(:module) do
#    desc "(Optional) An array of strings specifying netfilter kernel helper modules associated with this service"
#  end
#  
#  newparam(:destination) do
#    desc "(Optional) A hash specifying the destination network as a network IP address (optional with /mask), or a plain IP address. Valid hash keys are 'ipv4' and 'ipv6', with values corresponding to the IP / mask associated with each of those protocols. The use of hostnames is possible but not recommended, because these will only be resolved at service activation and transmitted to the kernel."
#  end
#  
#  newparam(:config_dir) do
#    desc "(Optional) The location where the service definition XML files will be stored. Defaults to /etc/firewalld/services"
#    defaultto '/etc/firewalld/services'
#  end

end
