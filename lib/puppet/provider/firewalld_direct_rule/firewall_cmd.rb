require 'puppet'

Puppet::Type.type(:firewalld_direct_rule).provide :firewall_cmd do
  desc "Interact with firewall-cmd"


  commands :firewall_cmd => 'firewall-cmd'

  def exists?
    @rule_args ||= build_direct_rule
    args=['--permanent', '--direct', '--query-rule', @rule_args].join(' ')
    output = %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    self.debug("Querying the firewalld direct interface for existing rules with: #{args}")
    if output.include?('yes')
      true
    else
      false
    end
  end

  def create
    self.debug("Adding new rule to firewalld: #{@resource[:name]}")
    @rule_args ||= build_direct_rule
    args=['--permanent', '--direct', '--add-rule', @rule_args].join(' ')
    %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    firewall_cmd(['--reload'])
  end

  def destroy
    self.debug("Removing rule from firewalld: #{@resource[:name]}")
    @rule_args ||= build_direct_rule
    args=['--permanent', '--direct', '--remove-rule', @rule_args].join(' ')
    %x{ /usr/bin/firewall-cmd #{args} 2>&1}
    firewall_cmd(['--reload'])
  end

  def build_direct_rule
     rule = []
     rule << [
	@resource[:inet_protocol],
	@resource[:table],
	@resource[:chain],
	@resource[:priority],
	@resource[:args],
     ]
  end

end
