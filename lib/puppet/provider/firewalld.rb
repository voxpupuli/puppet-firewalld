# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require 'puppet/provider'
require 'shellwords'

# Base provider class shared by all firewalld providers. It caches the
# running state of the firewalld service and provides helper methods for
# invoking firewall-cmd / firewall-offline-cmd.

class Puppet::Provider::Firewalld < Puppet::Provider
  @running = nil
  @runstate = nil

  class << self
    attr_accessor :running, :runstate
  end

  # Instance wrapper around the class-level cached running state.
  #
  # @return [Boolean, nil] true if firewalld is running, false if it is
  #   not, or nil if the state could not be determined.
  def state
    self.class.state
  end

  # Returns the cached running state of firewalld, checking it if it has
  # not already been determined.
  #
  # @return [Boolean, nil] true if firewalld is running, false if it is
  #   not, or nil if the state could not be determined.
  def self.state
    Puppet::Provider::Firewalld.runstate = check_running_state if Puppet::Provider::Firewalld.runstate.nil?
    Puppet::Provider::Firewalld.runstate
  end

  # Instance wrapper that delegates to the class-level state check.
  #
  # @return [Boolean, nil] true if firewalld is running, false if it is
  #   not, or nil if the executable could not be found.
  def check_running_state
    self.class.check_running_state
  end

  # Queries firewalld directly, via `firewall-cmd --state`, to determine
  # whether it is currently running.
  #
  # @return [Boolean, nil] true if firewalld is running, false if the
  #   command fails, or nil if the firewall-cmd executable is not
  #   available (eg: before the firewalld package is installed).
  def self.check_running_state
    debug("Executing --state command - current value #{@state}")
    ret = execute_firewall_cmd(['--state'], nil, nil, false, false, false)
    ret.exitstatus.zero?
  rescue Puppet::MissingCommand
    # This exception is caught in case the module is being run before
    # the package provider has installed the firewalld package, if we
    # cannot find the firewalld-cmd command then we silently continue
    # leaving @running set to nil, this will cause it to be re-checked
    # later in the execution process.
    #
    # See: https://github.com/crayfishx/puppet-firewalld/issues/96
    #
    debug('Could not determine state of firewalld because the executable is not available')
    nil
  end

  # v3.0.0
  #
  # Builds and runs a firewall-cmd (or firewall-offline-cmd, if firewalld is
  # not online) invocation with the given arguments.
  #
  # @param args [Array] the arguments to pass to the command
  # @param zone [String, nil] optional zone to target with --zone
  # @param policy [String, nil] optional policy to target with --policy
  # @param perm [Boolean] whether to add --permanent to the command
  # @param failonfail [Boolean] whether to raise if the command fails
  # @param check_online [Boolean] whether to check firewalld's online
  #   state to decide between firewall-cmd and firewall-offline-cmd
  #
  # @return [Puppet::Util::Execution::ProcessOutput] the command's output
  def self.execute_firewall_cmd(args, zone = nil, policy = nil, perm = true, failonfail = true, check_online = true)
    if check_online && !online?
      shell_cmd = 'firewall-offline-cmd'
      perm = false
    else
      shell_cmd = 'firewall-cmd'
    end
    cmd_args = []
    cmd_args << '--permanent' if perm
    cmd_args << ['--zone', zone] unless zone.nil?
    cmd_args << ['--policy', policy] unless policy.nil?

    # Add the arguments to our command string, removing any quotes, the command
    # provider will sort the quotes out.
    cmd_args << args.flatten.map { |a| a.delete("'") }

    # We can't use the commands short cut as some things, like exists? methods need to
    # allow for the command to fail, and there is no way to override that.  So instead
    # we interact with Puppet::Provider::Command directly to enable us to override
    # the failonfail option
    #
    firewall_cmd = Puppet::Provider::Command.new(
      :firewall_cmd,
      shell_cmd,
      Puppet::Util,
      Puppet::Util::Execution,
      failonfail: failonfail,
    )
    firewall_cmd.execute(cmd_args.flatten)
  end

  # Instance wrapper that runs a firewall-cmd invocation scoped to a zone.
  #
  # @param args [Array] the arguments to pass to the command
  # @param zone [String, nil] zone to target with --zone, defaults to the
  #   resource's zone
  # @param perm [Boolean] whether to add --permanent to the command
  # @param failonfail [Boolean] whether to raise if the command fails
  #
  # @return [Puppet::Util::Execution::ProcessOutput] the command's output
  def execute_firewall_cmd(args, zone = @resource[:zone], perm = true, failonfail = true)
    self.class.execute_firewall_cmd(args, zone, nil, perm, failonfail)
  end

  # Instance wrapper that runs a firewall-cmd invocation scoped to a policy.
  #
  # @param args [Array] the arguments to pass to the command
  # @param policy [String, nil] policy to target with --policy, defaults
  #   to the resource's policy
  # @param perm [Boolean] whether to add --permanent to the command
  # @param failonfail [Boolean] whether to raise if the command fails
  #
  # @return [Puppet::Util::Execution::ProcessOutput] the command's output
  def execute_firewall_cmd_policy(args, policy = @resource[:policy], perm = true, failonfail = true)
    self.class.execute_firewall_cmd(args, nil, policy, perm, failonfail)
  end

  # Arguments should be parsed as separate array entities, but quoted arg
  # eg --log-prefix 'IPTABLES DROPPED' should include the whole quoted part
  # in one element
  #
  def parse_args(args)
    args = args.flatten.join(' ') if args.is_a?(Array)
    args.split(%r{('[^']*'| )}).reject { |r| ['', ' '].include?(r) }
  end

  # Occasionally we need to restart firewalld in a transient way between resources
  # (eg: services) so the provider needs an an-hoc way of doing this since we can't
  # do it from the puppet level by notifying the service.
  def reload_firewall
    execute_firewall_cmd(['--reload'], nil, false) if online?
  end

  def offline?
    state == false || state.nil?
  end

  # Parses the output of `--list-all-zones` / `--list-all-policies` /
  # `--permanent --list-all-zones` / `--permanent --list-all-policies` into
  # a Hash keyed by zone/policy name. This lets callers fetch the services,
  # ports, and rich rules bound to every zone or policy with a single
  # firewall-cmd invocation instead of one invocation per zone/policy per
  # property.
  #
  # @param output [String] raw output of one of the --list-all-* commands
  # @return [Hash{String => Hash}] eg.
  #   { 'public' => { 'services' => ['ssh'], 'ports' => [{'port'=>'80','protocol'=>'tcp'}], 'rich_rules' => [] } }
  def self.parse_list_all(output)
    entries = {}
    name = nil
    output.each_line do |line|
      if line =~ %r{^(\S+)(?:\s+\(.*\))?\s*$} && !line.start_with?(' ', "\t")
        name = Regexp.last_match(1)
        entries[name] = { 'services' => [], 'ports' => [], 'rich_rules' => [] }
        next
      end
      next if name.nil?

      case line
      when %r{^\s+services:\s*(.*)$}
        entries[name]['services'] = Regexp.last_match(1).split
      when %r{^\s+ports:\s*(.*)$}
        entries[name]['ports'] = Regexp.last_match(1).split.map do |entry|
          port, protocol = entry.split('/')
          { 'port' => port, 'protocol' => protocol }
        end
      when %r{^\s+rich rules:\s*$}
        entries[name]['in_rich_rules'] = true
      when %r{^\t(.+)$}
        entries[name]['rich_rules'] << Regexp.last_match(1) if entries[name]['in_rich_rules']
      when %r{^\s+\S+:}
        entries[name]['in_rich_rules'] = false
      end
    end
    entries.each_value { |e| e.delete('in_rich_rules') }
    entries
  end

  # Parses the output of `--direct --get-all-chains` (format: "ipv table
  # chain" per line) into an Array of Hashes. Lets callers fetch every
  # direct chain with a single firewall-cmd invocation instead of one
  # --query-chain shellout per resource.
  #
  # @param output [String] raw output of --direct --get-all-chains
  # @return [Array<Hash{String=>String}>]
  def self.parse_all_chains(output)
    output.each_line.map do |line|
      line = line.chomp
      next nil if line.empty?

      inet_protocol, table, name = line.split(' ', 3)
      { 'inet_protocol' => inet_protocol, 'table' => table, 'name' => name }
    end.compact
  end

  # Parses the output of `--direct --get-all-rules` (format: "ipv table
  # chain priority args..." per line, args shell-quoted) into an Array of
  # Hashes. Lets callers fetch every direct rule with a single firewall-cmd
  # invocation instead of one --query-rule shellout per resource.
  #
  # @param output [String] raw output of --direct --get-all-rules
  # @return [Array<Hash>]
  def self.parse_all_rules(output)
    output.each_line.map do |line|
      line = line.chomp
      next nil if line.empty?

      inet_protocol, table, chain, priority, rest = line.split(' ', 5)
      {
        'inet_protocol' => inet_protocol,
        'table' => table,
        'chain' => chain,
        'priority' => priority,
        'args' => Shellwords.split(rest || ''),
      }
    end.compact
  end

  # Parses the output of `--direct --get-all-passthroughs` (format: "ipv
  # args..." per line, args shell-quoted) into an Array of Hashes. Lets
  # callers fetch every direct passthrough with a single firewall-cmd
  # invocation instead of one --query-passthrough shellout per resource.
  #
  # @param output [String] raw output of --direct --get-all-passthroughs
  # @return [Array<Hash>]
  def self.parse_all_passthroughs(output)
    output.each_line.map do |line|
      line = line.chomp
      next nil if line.empty?

      inet_protocol, rest = line.split(' ', 2)
      { 'inet_protocol' => inet_protocol, 'args' => Shellwords.split(rest || '') }
    end.compact
  end

  def online?
    self.class.online?
  end

  def self.online?
    # always re-check state unless we are already online:
    # see #117 / 813141cbfebf98c4348b64189cb472b6f3238c99
    # That means, `self.state` will be re-run, even if it has a valid value, such as `false`
    Puppet::Provider::Firewalld.runstate = check_running_state unless state == true
    state == true
  end

  # available? returns a true or false response as to whether firewalld is availabe.
  # unlike online? it will only return false if it is unable to determine the status
  # of firewalld, normally due to the fact that the package isn't installed yet.
  #
  def available?
    self.class.available?
  end

  def self.available?
    !state.nil?
  end
end
