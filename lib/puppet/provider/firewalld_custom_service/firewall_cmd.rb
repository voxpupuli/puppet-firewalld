require 'puppet'

Puppet::Type.type(:firewalld_custom_service).provide :firewall_cmd do
  desc "Interact with firewall-cmd"


  commands :firewall_cmd => 'firewall-cmd'


  def exec_firewall(*extra_args)
    args=[]
    args << '--permanent'
    args << extra_args
    args.flatten!
    firewall_cmd(args)
  end

  def exists?
    exec_firewall('--get-services').split(/ /).include?(@resource[:name])
  end

  def create
    exec_firewall('--new-service', @resource[:name])
  end

  def destroy
    exec_firewall('--delete-service', @resource[:name])
  end

end
