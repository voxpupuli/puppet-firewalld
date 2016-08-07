require 'puppet'
require 'puppet/type'
require 'puppet/provider'
class Puppet::Provider::Firewalld < Puppet::Provider


 
  # v3.0.0
  def self.execute_firewall_cmd(args,  zone=nil, perm=true, failonfail=true, shell_cmd='firewall-cmd')
    cmd_args = []
    cmd_args << '--permanent' if perm
    cmd_args << [ '--zone', zone ] unless zone.nil?
    cmd_args << args

    firewall_cmd = Puppet::Provider::Command.new(
      :firewall_cmd,
      shell_cmd,
      Puppet::Util,
      Puppet::Util::Execution,
      { :failonfail => failonfail }
    )
   firewall_cmd.execute(cmd_args.flatten)
  end

  def execute_firewall_cmd(args, zone=@resource[:zone], perm=true, failonfail=true)
    begin
      self.class.execute_firewall_cmd(args, zone, perm, failonfail)
    rescue Puppet::ExecutionFailure
      # Last ditch effort to see if we're seeing an error becuse firewalld is offline.
      # This could be the case if we're calling providers from the generate method
      # of firewalld_zone before we can manage the service.
      #
      self.class.execute_firewall_cmd(args, zone, false, true, 'firewall-offline-cmd')
    end
  end

end
