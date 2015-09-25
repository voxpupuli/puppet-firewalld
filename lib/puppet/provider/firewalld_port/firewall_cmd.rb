require 'puppet'

Puppet::Type.type(:firewalld_port).provide :firewall_cmd do
  desc "Interact with firewall-cmd"
  
  commands :firewall_cmd => 'fiewall-cmd'
  
  mk_resource_methods
  
  def exists?
    @rule_args ||= build_port_rule
    args=['--permanent','--zone',@resource[:zone],'--query-port',"'#[@rule_args}'}].join(' ')
    %x{/usr/bin/firewall-cmd #{args} }
    $?.success?
  end
  
  def quote_keyval(key,val)
    val ? "#{key}=\"#{val}\"" : ''
  end
  
  def eval_port
    args = []
    args << [quote_keyval('port',@resource[:port]['port']),quote_keyval('protocol, @resource[:port]['protocol'])].join("/")
    args
  end
  
  def build_port_rule
    return @resource[:raw_rule] if @resource[:raw_rule]
    rule = []
    rule << eval_port
    @resource[:raw_rule] = rule.flatten.reject { |r| r.empty? }.join(" ")
    @resource[:raw_rule]
  end
  
  def firewall_cmd_run(opt)
      args = []
      args << [ '--permanent', '--zone', @resource[:zone] ]
      args << opt
      args << "'#{@resource[:raw_rule]}'"
      output = %x{/usr/bin/firewall-cmd #{args.flatten.join(' ')} 2>&1}
      raise Puppet::Error, "Failed to run firewall rule: #{output}" unless $?.success?
      output = %x{/usr/bin/firewall-cmd --reload 2>&1}
      raise Puppet::Error, "Failed to reload firewall rule: #{output}" unless $?.success?
  end
  
  def create
    firewall_cmd_run('--add-port')
  end
  
  def destroy
    firewall_cmd_run('--remove-port')
  end
  
end
