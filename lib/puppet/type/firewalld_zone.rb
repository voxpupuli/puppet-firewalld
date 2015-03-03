require 'puppet'

Puppet::Type.newtype(:firewalld_zone) do

  ensurable

  newparam(:name) do
    desc "Name of the rule resource in Puppet"
  end

  newparam(:zone) do
    desc "Name of the zone"
  end

  newproperty(:target) do
    desc "Specify the target for the zone"
  end

end

