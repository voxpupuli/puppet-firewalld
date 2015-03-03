require 'puppet'

Puppet::Type.newtype(:firewalld_rich_rule) do

  ensurable

  newparam(:name) do
    desc "Name of the rule resource in Puppet"
  end

  newparam(:zone) do
    desc "Name of the zone"
  end

  newparam(:family) do
    desc "IP family, one of ipv4 or ipv6, defauts to ipv4"
    newvalues(:ipv4, :ipv6)
    defaultto :ipv4
  end

  newparam(:source) do
    desc "Specify source address, this can be a string of the IP address or a hash containing other options"
    munge do |value|
      if value.is_a?(String)
        { 'address' => value }
      else
        value
      end
    end
  end
  newparam(:dest) do
    desc "Specify destination address, this can be a string of the IP address or a hash containing other options"
    munge do |value|
      if value.is_a?(String)
        { 'address' => value }
      else
        value
      end
    end
  end

  newparam(:service) do
    desc "Specify the element as a service"
  end

  newparam(:port) do
    desc "Specify the element as a port"
  end

  newparam(:protocol) do
    desc "Specify the element as a protocol"
  end

  newparam(:icmp_block) do
    desc "Specify the element as an icmp-block"
  end

  newparam(:masquerade) do
    desc "Specify the element as masquerade"
  end

  newparam(:forward_port) do
    desc "Specify the element as forward-port"
  end

  newparam(:log) do
    desc "doc"
  end

  newparam(:audit) do
    desc "doc"
  end

  newparam(:action) do
    desc "doc"
  end
 
  ELEMENTS = [:service, :port, :protocol, :icmp_block, :masquerade, :forward_port]
  validate do
    errormsg = "Only one element (#{ELEMENTS.join(',')}) may be specified."
    self.fail errormsg if ELEMENTS.select { |e| self[e] }.size > 1
  end

  autorequire(:firewalld_zone) do
    self[:zone]
  end


end
