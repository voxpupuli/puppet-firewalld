require 'puppet'
require 'puppet/provider/firewalld'

Puppet::Type.type(:firewalld_direct_purge).provide(
  :firewall_cmd,
  :parent => Puppet::Provider::Firewalld
) do
  desc "Meta provider to the firewalld_direct_purge type"

  def get_instances_of(restype)
    raise Puppet::Error, "Unknown type #{restype}" unless [:chain, :passthrough, :rule].include?(restype)
    output = execute_firewall_cmd(['--direct',"--get-all-#{restype.to_s}s"], nil)
    output.split(/\n/)
  end

  def purge_resources(restype, args)
    raise Puppet::Error, "Unknown type #{restype}" unless [:chain, :passthrough, :rule].include?(restype)
    execute_firewall_cmd(['--direct', "--remove-#{restype.to_s}", args], nil)
  end

end
