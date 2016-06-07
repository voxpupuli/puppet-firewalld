require 'puppet'

Puppet::Type.type(:firewalld_direct_chain).provide :firewall_cmd do
  desc "Interact with firewall-cmd"


  commands :firewall_cmd => 'firewall-cmd'

  def exists?
    @chain_args ||= build_direct_chain
    args=['--permanent', '--direct', '--query-chain', @chain_args].join(' ')
    output = %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    self.debug("Querying the firewalld direct interface for existing chain with: #{args}")
    if output.include?('yes')
      true
    else
      false
    end
  end

  def create
    self.debug("Adding new custom chain to firewalld: #{@resource[:name]}")
    @chain_args ||= build_direct_chain
    args=['--permanent', '--direct', '--add-chain', @chain_args].join(' ')
    %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    firewall_cmd(['--reload'])
  end

  def destroy
    self.debug("Removing custom chain from firewalld: #{@resource[:name]}")
    @chain_args ||= build_direct_chain
    args=['--permanent', '--direct', '--remove-chain', @chain_args].join(' ')
    %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    firewall_cmd(['--reload'])
  end

  def build_direct_chain
     chain = []
     chain << [
	@resource[:inet_protocol],
	@resource[:table],
	@resource[:custom_chain]
     ]
  end

end
