# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_policy).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  # Lists every existing policy with a single firewall-cmd invocation.
  # Unlike firewalld_service's predefined service catalog, --get-policies
  # does reflect real configured policies, so it's safe to use directly
  # here.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.all_policies
    execute_firewall_cmd(['--get-policies'], nil).split
  end

  def self.instances
    all_policies.map { |p| new(ensure: :present, name: p) }
  end

  # firewalld_policy's namevar is the policy name itself (unlike
  # firewalld_service, where the Puppet title and the firewalld-level name
  # can differ), so resources can safely be matched by name.
  #
  def self.prefetch(resources)
    policies = all_policies

    resources.each_value do |resource|
      resource.provider = new(ensure: policies.include?(resource[:name]) ? :present : :absent, name: resource[:name])
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow have no prefetched state, so fall back to a
  # live query for those.
  def exists?
    @resource[:policy] = @resource[:name]
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

    execute_firewall_cmd_policy(['--get-policies'], nil).split.include?(@resource[:name])
  end

  def create
    debug("Creating new policy #{@resource[:name]} with target: '#{@resource[:target]}'")
    execute_firewall_cmd_policy(['--new-policy', @resource[:name]], nil)

    self.target = (@resource[:target]) if @resource[:target]
    self.ingress_zones = @resource[:ingress_zones]
    self.egress_zones = @resource[:egress_zones]
    self.priority = @resource[:priority] if @resource[:priority]
    self.icmp_blocks = (@resource[:icmp_blocks]) if @resource[:icmp_blocks]
    self.description = (@resource[:description]) if @resource[:description]
    self.short = (@resource[:short]) if @resource[:short]
  end

  def destroy
    debug("Deleting policy #{@resource[:name]}")
    execute_firewall_cmd_policy(['--delete-policy', @resource[:name]], nil)
  end

  def target
    policy_target = execute_firewall_cmd_policy(['--get-target']).chomp
    # The firewall-cmd may or may not return the target surrounded by
    # %% depending on the version. See:
    # https://github.com/crayfishx/puppet-firewalld/issues/111
    return @resource[:target] if @resource[:target].delete('%') == policy_target

    policy_target
  end

  def target=(__target)
    debug("Setting target for policy #{@resource[:name]} to #{@resource[:target]}")
    execute_firewall_cmd_policy(['--set-target', @resource[:target]])
  end

  def ingress_zones
    execute_firewall_cmd_policy(['--list-ingress-zones']).chomp.split || []
  end

  def ingress_zones=(new_ingress_zones)
    new_ingress_zones ||= []
    cur_ingress_zones = ingress_zones
    # Current zones that the policy is not applied to in the catalog
    # must be removed first or we might end up trying to add a regular
    # zone to a policy that currently applies to ANY or HOST.
    (cur_ingress_zones - new_ingress_zones).each do |extraneous_zone|
      debug("Removing ingress zone '#{extraneous_zone}' from policy #{@resource[:name]}")
      execute_firewall_cmd_policy(['--remove-ingress-zone', extraneous_zone])
    end
    (new_ingress_zones - cur_ingress_zones).each do |missing_zone|
      debug("Adding ingress zone '#{missing_zone}' to policy #{@resource[:name]}")
      execute_firewall_cmd_policy(['--add-ingress-zone', missing_zone])
    end
  end

  def egress_zones
    execute_firewall_cmd_policy(['--list-egress-zones']).chomp.split || []
  end

  def egress_zones=(new_egress_zones)
    new_egress_zones ||= []
    cur_egress_zones = egress_zones
    # Current zones that the policy is not applied to in the catalog
    # must be removed first or we might end up trying to add a regular
    # zone to a policy that currently applies to ANY or HOST.
    (cur_egress_zones - new_egress_zones).each do |extraneous_zone|
      debug("Removing egress zone '#{extraneous_zone}' from policy #{@resource[:name]}")
      execute_firewall_cmd_policy(['--remove-egress-zone', extraneous_zone])
    end
    (new_egress_zones - cur_egress_zones).each do |missing_zone|
      debug("Adding egress zone '#{missing_zone}' to policy #{@resource[:name]}")
      execute_firewall_cmd_policy(['--add-egress-zone', missing_zone])
    end
  end

  def priority
    execute_firewall_cmd_policy(['--get-priority']).chomp
  end

  def priority=(new_priority)
    execute_firewall_cmd_policy(['--set-priority', new_priority])
  end

  def masquerade
    if execute_firewall_cmd_policy(['--query-masquerade'], @resource[:name], true, false).chomp == 'yes'
      :true
    else
      :false
    end
  end

  def masquerade=(bool)
    case bool
    when :true
      execute_firewall_cmd_policy(['--add-masquerade'])
    when :false
      execute_firewall_cmd_policy(['--remove-masquerade'])
    end
  end

  def icmp_blocks
    get_icmp_blocks
  end

  def icmp_blocks=(new_icmp_blocks)
    set_blocks = []
    remove_blocks = []

    icmp_types = get_icmp_types

    case new_icmp_blocks
    when Array
      get_icmp_blocks.each do |remove_block|
        unless new_icmp_blocks.include?(remove_block)
          debug("removing block #{remove_block} from policy #{@resource[:name]}")
          remove_blocks.push(remove_block)
        end
      end

      new_icmp_blocks.each do |block|
        raise Puppet::Error, 'parameter icmp_blocks must be a string or array of strings!' unless block.is_a?(String)

        if icmp_types.include?(block)
          debug("adding block #{block} to policy #{@resource[:name]}")
          set_blocks.push(block)
        else
          valid_types = icmp_types.join(', ')
          raise Puppet::Error, "#{block} is not a valid icmp type on this system! Valid types are: #{valid_types}"
        end
      end
    when String
      get_icmp_blocks.reject { |x| x == new_icmp_blocks }.each do |remove_block|
        debug("removing block #{remove_block} from policy #{@resource[:name]}")
        remove_blocks.push(remove_block)
      end
      if icmp_types.include?(new_icmp_blocks)
        debug("adding block #{new_icmp_blocks} to policy #{@resource[:name]}")
        set_blocks.push(new_icmp_blocks)
      else
        valid_types = icmp_types.join(', ')
        raise Puppet::Error, "#{new_icmp_blocks} is not a valid icmp type on this system! Valid types are: #{valid_types}"
      end
    else
      raise Puppet::Error, 'parameter icmp_blocks must be a string or array of strings!'
    end
    unless remove_blocks.empty?
      remove_blocks.each do |block|
        execute_firewall_cmd_policy(['--remove-icmp-block', block])
      end
    end
    unless set_blocks.empty? # rubocop:disable Style/GuardClause
      set_blocks.each do |block|
        execute_firewall_cmd_policy(['--add-icmp-block', block])
      end
    end
  end

  # rubocop:disable Style/AccessorMethodName
  def get_rules
    perm = execute_firewall_cmd_policy(['--list-rich-rules']).split(%r{\n})
    curr = execute_firewall_cmd_policy(['--list-rich-rules'], @resource[:name], false).split(%r{\n})
    [perm, curr].flatten.uniq
  end

  def get_services
    perm = execute_firewall_cmd_policy(['--list-services']).split
    curr = execute_firewall_cmd_policy(['--list-services'], @resource[:name], false).split
    [perm, curr].flatten.uniq
  end

  def get_ports
    perm = execute_firewall_cmd_policy(['--list-ports']).split
    curr = execute_firewall_cmd_policy(['--list-ports'], @resource[:name], false).split

    [perm, curr].flatten.uniq.map do |entry|
      port, protocol = entry.split(%r{/})
      debug("get_ports() Found port #{port} protocol #{protocol}")
      { 'port' => port, 'protocol' => protocol }
    end
  end

  def get_icmp_blocks
    execute_firewall_cmd_policy(['--list-icmp-blocks']).split.sort
  end

  def get_icmp_types
    execute_firewall_cmd_policy(['--get-icmptypes'], nil).split
  end
  # rubocop:enable Style/AccessorMethodName

  def description
    execute_firewall_cmd_policy(['--get-description'], @resource[:name], true, false)
  end

  def description=(new_description)
    execute_firewall_cmd_policy(['--set-description', new_description], @resource[:name], true, false)
  end

  def short
    execute_firewall_cmd_policy(['--get-short'], @resource[:name], true, false)
  end

  def short=(new_short)
    execute_firewall_cmd_policy(['--set-short', new_short], @resource[:name], true, false)
  end

  def flush
    reload_firewall
  end
end
