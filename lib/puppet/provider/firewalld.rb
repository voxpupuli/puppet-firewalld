require 'puppet'
require 'puppet/type'
require 'puppet/provider'
class Puppet::Provider::Firewalld < Puppet::Provider


 
  # v3.0.0
  def self.execute_firewall_cmd(args,  zone=nil, perm=true, failonfail=true)
    cmd_args = []
    cmd_args << '--permanent' if perm
    cmd_args << [ '--zone', zone ] unless zone.nil?
    cmd_args << args

    firewall_cmd ||= Puppet::Provider::Command.new(
      :firewall_cmd,
      'firewall-cmd',
      Puppet::Util,
      Puppet::Util::Execution,
      { :failonfail => failonfail }
    )
    firewall_cmd.execute(cmd_args.flatten)
  end

  def execute_firewall_cmd(args, zone=@resource[:zone], perm=true, failonfail=true)
    self.class.execute_firewall_cmd(args, zone, perm, failonfail)
  end

end
