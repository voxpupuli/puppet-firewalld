require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_direct_chain).provide(:firewall_cmd, parent: Puppet::Provider::Firewalld) do
  desc 'Provider for managing firewalld direct chains using firewall-cmd'

  def initialize(value = {})
    super(value)
    @in_perm = false
    @in_run = false
  end

  def exists?
    @chain_args ||= generate_raw
    @in_perm = execute_firewall_cmd(['--direct', '--query-chain', @chain_args], nil, true, false).include?('yes')
    @in_run = execute_firewall_cmd(['--direct', '--query-chain', @chain_args], nil, false, false).include?('yes')
    if @resource[:ensure] == :present
      @in_perm && @in_run
    else
      @in_perm || @in_run
    end
  end

  def create
    @chain_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--add-chain', @chain_args], nil) unless @in_perm
  end

  def destroy
    @chain_args ||= generate_raw
    execute_firewall_cmd(['--direct', '--remove-chain', @chain_args], nil) if @in_perm
  end

  def generate_raw
    chain = []
    chain << [
      @resource[:inet_protocol],
      @resource[:table],
      @resource[:name]
    ]
  end
end
