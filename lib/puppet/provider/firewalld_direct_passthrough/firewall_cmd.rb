require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_direct_passthrough).provide(
  :firewalld_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  def initialize(value = {})
    super(value)
    @in_perm = false
    @in_run = false
  end

  def exists?
    @passt_args ||= generate_raw
    @in_perm = execute_firewall_cmd(['--direct', '--query-passthrough', @passt_args], nil, true, false).include?('yes')
    @in_run = execute_firewall_cmd(['--direct', '--query-passthrough', @passt_args], nil, false, false).include?('yes')
    if @resource[:ensure] == :present
      @in_perm && @in_run
    else
      @in_perm || @in_run
    end
  end

  def create
    @passt_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--add-passthrough', @passt_args], nil) unless @in_perm
  end

  def destroy
    @passt_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--remove-passthrough', @passt_args], nil) if @in_perm
  end

  def generate_raw
    passt = []
    passt << [
      @resource[:inet_protocol],
      parse_args(@resource[:args])
    ]
    passt.flatten
  end
end
