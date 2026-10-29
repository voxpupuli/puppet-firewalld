# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require 'puppet/provider'

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
