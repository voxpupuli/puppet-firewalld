require 'puppet'
require 'puppet/type'
require 'puppet/provider'
class Puppet::Provider::Firewalld < Puppet::Provider
  @running = nil
  @runstate = nil

  class << self
    attr_accessor :running
    attr_accessor :runstate
  end

  def state
    self.class.state
  end

  def self.state
    if Puppet::Provider::Firewalld.runstate.nil?
      Puppet::Provider::Firewalld.runstate = check_running_state
    end
    Puppet::Provider::Firewalld.runstate
  end

  def check_running_state
    self.class.check_running_state
  end

  def self.check_running_state
    debug("Executing --state command - current value #{@state}")
    ret = execute_firewall_cmd(['--state'], nil, false, false, false)
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
    return nil
  end

  # v3.0.0
  def self.execute_firewall_cmd(args, zone = nil, perm = true, failonfail = true, check_online = true)
    if check_online && !online?
      shell_cmd = 'firewall-offline-cmd'
      perm = false
    else
      shell_cmd = 'firewall-cmd'
    end
    cmd_args = []
    cmd_args << '--permanent' if perm
    cmd_args << ['--zone', zone] unless zone.nil?

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
      failonfail: failonfail
    )
    firewall_cmd.execute(cmd_args.flatten)
  end

  def execute_firewall_cmd(args, zone = @resource[:zone], perm = true, failonfail = true)
    self.class.execute_firewall_cmd(args, zone, perm, failonfail)
  end

  # Arguments should be parsed as separate array entities, but quoted arg
  # eg --log-prefix 'IPTABLES DROPPED' should include the whole quoted part
  # in one element
  #
  def parse_args(args)
    args = args.flatten.join(' ') if args.is_a?(Array)
    args.split(%r{(\'[^\']*\'| )}).reject { |r| ['', ' '].include?(r) }
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
