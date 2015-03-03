require 'puppet'

Puppet::Type.type(:firewalld_zone).provide :firewall_cmd do
  desc "Interact with firewall-cmd"


  commands :firewall_cmd => 'firewall-cmd'


  def exec_firewall(*extra_args)
    args=[]
    args << '--permanent'
    args << extra_args
    args.flatten!
    firewall_cmd(args)
  end

  def zone_exec_firewall(*extra_args)
    args = [ '--zone', @resource[:name]]
    exec_firewall(args, extra_args)
  end

  def exists?
    exec_firewall('--get-zones').split(/ /).include?(@resource[:name])
  end

  def create
    exec_firewall('--new-zone', @resource[:name])
    self.target=(@resource[:target]) 
  end

  def destroy
    exec_firewall('--delete-zone', @resource[:name])
  end

  def target
    zone_exec_firewall('--get-target').chomp
  end

  def target=(t)
    zone_exec_firewall('--set-target', @resource[:target])
  end

  ## TODO: Add ICM blocks, ports and other zone options


end

