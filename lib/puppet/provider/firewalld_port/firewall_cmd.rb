require 'puppet'

Puppet::Type.type(:firewalld_port).provide :firewall_cmd do
  desc "Interact with firewall-cmd"
  
  commands :firewall_cmd => 'firewall-cmd'
  
  mk_resource_methods
  
  def exists?
    @rule_args ||= build_port_rule
    args=['--zone', @resource[:zone],'--query-port', @rule_args ]
    #%x{/usr/bin/firewall-cmd #{args} }
    #$?.success? 
    begin
      firewall_cmd(args)
      true
    rescue Puppet::ExecutionFailure => e
      false
    end
  end
  
  def quote_keyval(key,val)
    val ? "#{key}=\"#{val}\"" : ''
  end
  
  def eval_port
    args = []
    args << "#{@resource[:port]}/#{@resource[:protocol]}"
    args
  end
  
  def build_port_rule
    #return @resource[:port] if @resource[:port]
    rule = []
    rule << eval_port
    #@resource[:port] = rule.flatten.reject { |r| r.empty? }.join(" ")
    #@resource[:port]
    rule
  end
  
  def firewall_cmd_run(opt)
      args = []
      args << [ '--permanent', '--zone', @resource[:zone] ]
      args << opt
      #args << "'#{@resource[:port]}'"
      args << build_port_rule 
      firewall_cmd(args)
      firewall_cmd(["--reload"])
  end
  
  def create
    firewall_cmd_run('--add-port')
  end
  
  def destroy
    firewall_cmd_run('--remove-port')
  end
  
end
