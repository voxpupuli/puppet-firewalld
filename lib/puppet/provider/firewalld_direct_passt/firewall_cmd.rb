require 'puppet'

Puppet::Type.type(:firewalld_direct_passt).provide :firewall_cmd do
  desc "Interact with firewall-cmd"


  commands :firewall_cmd => 'firewall-cmd'

  def exists?
    @passt_args ||= build_direct_passt
    args=['--permanent', '--direct', '--query-passthrough', @passt_args].join(' ')
    output = %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    self.debug("Querying the firewalld direct interface for existing passthrough with: #{args}")
    if output.include?('yes')
      true
    else
      false
    end
  end

  def create
    self.debug("Adding new custom passthrough to firewalld: #{@resource[:name]}")
    @passt_args ||= build_direct_passt
    args=['--permanent', '--direct', '--add-passthrough', @passt_args].join(' ')
    %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    firewall_cmd(['--reload'])
  end

  def destroy
    self.debug("Removing custom passthrough from firewalld: #{@resource[:name]}")
    @passt_args ||= build_direct_passt
    args=['--permanent', '--direct', '--remove-passthrough', @passt_args].join(' ')
    %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    firewall_cmd(['--reload'])
  end

  def build_direct_passt
     passt = []
     passt << [
	@resource[:inet_protocol],
	@resource[:args]
     ]
  end

end
