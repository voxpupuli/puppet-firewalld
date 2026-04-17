# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require 'puppet/provider'
class Puppet::Provider::Firewalld < Puppet::Provider
  @running = nil
  @runstate = nil

  class << self
    attr_accessor :running, :runstate
  end

  # Transaction-scoped cache shared by provider subclasses that perform
  # bulk introspection (e.g. `firewall-cmd --list-all-zones`). The cache
  # is intentionally class-level so that getters invoked after prefetch
  # can find the parsed data without re-shelling.
  #
  # Invalidated on reload_firewall (see below) and explicitly from specs
  # via invalidate_cache!.
  def self.catalog_cache
    @catalog_cache ||= {}
  end

  def self.invalidate_cache!(key = nil)
    if key.nil?
      @catalog_cache = {}
    elsif @catalog_cache
      @catalog_cache.delete(key)
    end
  end

  # Parse the output of `firewall-cmd --list-all-zones` or
  # `firewall-cmd --list-all-policies`. Both commands emit the same
  # block-style format:
  #
  #   <name> (active)
  #     target: default
  #     icmp-block-inversion: no
  #     interfaces: eth0 eth1
  #     sources:
  #     services: ssh dhcpv6-client
  #     ...
  #
  # Returns a Hash keyed by zone/policy name whose values are Hashes of
  # `property => parsed_value`. The parser is intentionally permissive:
  # unknown keys are retained (as strings) and missing keys are simply
  # absent from the inner Hash, letting callers fall back to per-property
  # queries when needed.
  def self.parse_list_all_output(text)
    result = {}
    return result if text.nil? || text.empty?

    current_name = nil
    current = nil
    current_list_key = nil

    text.each_line do |line|
      line = line.chomp
      next if line.empty?

      # Top-level entries start at column 0 and contain the name
      # optionally followed by " (active)" or " (default)".
      if line =~ %r{\A(\S+)(?:\s+\([^)]+\))?\s*\z}
        current_name = Regexp.last_match(1)
        current = {}
        result[current_name] = current
        current_list_key = nil
        next
      end

      next if current.nil?

      # Continuation lines for list-valued keys start with a tab or
      # multiple spaces and have no "key:" prefix. firewalld uses this
      # format for `rich rules:` where each rule is on its own line.
      if line =~ %r{\A\s+(\S.*)\z} && line !~ %r{\A\s+[\w-]+:\s*(?:.*)\z}
        (current[current_list_key] ||= []) << Regexp.last_match(1).strip if current_list_key
        next
      end

      # Standard "  key: value" line.
      next unless line =~ %r{\A\s+([\w-]+):\s*(.*)\z}

      key = Regexp.last_match(1)
      value = Regexp.last_match(2)
      current_list_key = key
      current[key] = value
    end

    result
  end

  def state
    self.class.state
  end

  def self.state
    Puppet::Provider::Firewalld.runstate = check_running_state if Puppet::Provider::Firewalld.runstate.nil?
    Puppet::Provider::Firewalld.runstate
  end

  def check_running_state
    self.class.check_running_state
  end

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

  def execute_firewall_cmd(args, zone = @resource[:zone], perm = true, failonfail = true)
    self.class.execute_firewall_cmd(args, zone, nil, perm, failonfail)
  end

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
    return unless online?

    execute_firewall_cmd(['--reload'], nil, false)
    # Any bulk-prefetched state captured before the reload may no longer
    # reflect on-disk state, so drop it and force subsequent resources to
    # re-read authoritatively.
    Puppet::Provider::Firewalld.invalidate_cache!
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
