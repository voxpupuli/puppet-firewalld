
Puppet::Type.newtype(:firewalld_ipset) do

  @doc =%q{
    Configure IPsets in Firewalld
    
    Example:
    
        firewalld_ipset {'internal net':
            ensure   => 'present',
            type     => 'hash:net',
            family   => 'inet',
            entries  => ['192.168.0.0/24']
        }
  }
  
  ensurable
  
  newparam(:name, :namevar => true) do
    desc "Name of the IPset"
    validate do |val|
      raise Puppet::Error, "IPset name must be a word with no spaces" unless val =~ /^\w+$/
    end
  end
  
  newparam(:type) do
    desc "Type of the ipset (default: hash:ip)"
    defaultto "hash:ip"
    newvalues(:'bitmap:ip', :'bitmap:ip,mac', :'bitmap:port', :'hash:ip', :'hash:ip,mark', :'hash:ip,port', :'hash:ip,port,ip', :'hash:ip,port,net', :'hash:mac', :'hash:net', :'hash:net,iface', :'hash:net,net', :'hash:net,port', :'hash:net,port,net', :'list:set')
  end

  newparam(:options) do
    desc "Hash of options for the IPset, eg { 'family' => 'inet6' }"
    validate do |val|
      raise Puppet::Error, "options must be a hash" unless val.is_a?(Hash)
    end
  end

  newproperty(:entries, :array_matching => :all) do
    desc "Array of ipset entries"
    def insync?(is)
      should.sort == is
    end
  end

end
  
