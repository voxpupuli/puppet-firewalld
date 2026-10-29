# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_zone).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  # Lists every existing zone with a single firewall-cmd invocation. Unlike
  # firewalld_service's predefined service catalog, --get-zones does reflect
  # real configured zones, so it's safe to use directly here.
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.all_zones
    execute_firewall_cmd(['--get-zones'], nil).split
  end

  def self.instances
    all_zones.map { |z| new(ensure: :present, name: z) }
  end

  # firewalld_zone's namevar is the zone name itself (unlike
  # firewalld_service, where the Puppet title and the firewalld-level name
  # can differ), so resources can safely be matched by name.
  #
  def self.prefetch(resources)
    zones = all_zones

    resources.each_value do |resource|
      resource.provider = new(ensure: zones.include?(resource[:name]) ? :present : :absent, name: resource[:name])
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow have no prefetched state, so fall back to a
  # live query for those.
  def exists?
    @resource[:zone] = @resource[:name]
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

    execute_firewall_cmd(['--get-zones'], nil).split.include?(@resource[:name])
  end

  def create
    debug("Creating new zone #{@resource[:name]} with target: '#{@resource[:target]}'")
    execute_firewall_cmd(['--new-zone', @resource[:name]], nil)

    self.target = (@resource[:target]) if @resource[:target]
    self.sources = (@resource[:sources]) if @resource[:sources]
    self.protocols = (@resource[:protocols]) if @resource[:protocols]
    self.interfaces = @resource[:interfaces]
    self.icmp_blocks = (@resource[:icmp_blocks]) if @resource[:icmp_blocks]
    self.icmp_block_inversion = (@resource[:icmp_block_inversion]) if @resource[:icmp_block_inversion]
    self.description = (@resource[:description]) if @resource[:description]
    self.short = (@resource[:short]) if @resource[:short]
  end

  def destroy
    debug("Deleting zone #{@resource[:name]}")
    execute_firewall_cmd(['--delete-zone', @resource[:name]], nil)
  end

  def target
    zone_target = execute_firewall_cmd(['--get-target']).chomp
    # The firewall-cmd may or may not return the target surrounded by
    # %% depending on the version. See:
    # https://github.com/crayfishx/puppet-firewalld/issues/111
    return @resource[:target] if @resource[:target].delete('%') == zone_target

    zone_target
  end

  def target=(__target)
    debug("Setting target for zone #{@resource[:name]} to #{@resource[:target]}")
    execute_firewall_cmd(['--set-target', @resource[:target]])
  end

  def interfaces
    execute_firewall_cmd(['--list-interfaces']).chomp.split || []
  end

  # NOTE: --add-interface and --remove-interface must never be combined in
  # a single firewall-cmd invocation: firewall-cmd's argument parsing only
  # acts on the first recognized action flag it sees, so a mixed call would
  # silently drop everything after it. Repeating the *same* flag for
  # multiple values is fine and is what collapses N calls into one here.
  def interfaces=(new_interfaces)
    new_interfaces ||= []
    cur_interfaces = interfaces
    missing_interfaces = new_interfaces - cur_interfaces
    extraneous_interfaces = cur_interfaces - new_interfaces

    missing_interfaces.each { |i| debug("Adding interface '#{i}' to zone #{@resource[:name]}") }
    extraneous_interfaces.each { |i| debug("Removing interface '#{i}' from zone #{@resource[:name]}") }

    execute_firewall_cmd(batch_flag('--add-interface', missing_interfaces)) unless missing_interfaces.empty?
    execute_firewall_cmd(batch_flag('--remove-interface', extraneous_interfaces)) unless extraneous_interfaces.empty?
  end

  def sources
    execute_firewall_cmd(['--list-sources']).chomp.split.sort || []
  end

  # See the note on interfaces= above: --add-source and --remove-source must
  # not be combined in a single firewall-cmd invocation.
  def sources=(new_sources)
    new_sources ||= []
    cur_sources = sources
    missing_sources = new_sources - cur_sources
    extraneous_sources = cur_sources - new_sources

    missing_sources.each { |s| debug("Adding source '#{s}' to zone #{@resource[:name]}") }
    extraneous_sources.each { |s| debug("Removing source '#{s}' from zone #{@resource[:name]}") }

    execute_firewall_cmd(batch_flag('--add-source', missing_sources)) unless missing_sources.empty?
    execute_firewall_cmd(batch_flag('--remove-source', extraneous_sources)) unless extraneous_sources.empty?
  end

  def protocols
    execute_firewall_cmd(['--list-protocols']).chomp.split.sort || []
  end

  # See the note on interfaces= above: --add-protocol and --remove-protocol
  # must not be combined in a single firewall-cmd invocation.
  def protocols=(new_protocols)
    new_protocols ||= []
    cur_protocols = protocols
    missing_protocols = new_protocols - cur_protocols
    extraneous_protocols = cur_protocols - new_protocols

    missing_protocols.each { |p| debug("Adding protocol '#{p}' to zone #{@resource[:name]}") }
    extraneous_protocols.each { |p| debug("Removing protocol '#{p}' from zone #{@resource[:name]}") }

    execute_firewall_cmd(batch_flag('--add-protocol', missing_protocols)) unless missing_protocols.empty?
    execute_firewall_cmd(batch_flag('--remove-protocol', extraneous_protocols)) unless extraneous_protocols.empty?
  end

  def masquerade
    if execute_firewall_cmd(['--query-masquerade'], @resource[:name], true, false).chomp == 'yes'
      :true
    else
      :false
    end
  end

  def masquerade=(bool)
    case bool
    when :true
      execute_firewall_cmd(['--add-masquerade'], @resource[:name])
    when :false
      execute_firewall_cmd(['--remove-masquerade'], @resource[:name])
    end
  end

  def icmp_blocks
    get_icmp_blocks
  end

  def icmp_blocks=(new_icmp_blocks)
    new_icmp_blocks = new_icmp_blocks.split(%r{\s+}) if new_icmp_blocks.is_a?(String)
    raise Puppet::Error, 'parameter icmp_blocks must be a string or array of strings!' unless new_icmp_blocks.is_a?(Array)

    icmp_types = get_icmp_types
    invalid_blocks = new_icmp_blocks - icmp_types
    raise Puppet::Error, "Invalid ICMP types: '#{invalid_blocks.join(', ')}'! Valid types are: '#{icmp_types.join(', ')}'" unless invalid_blocks.empty?

    icmp_blocks = get_icmp_blocks

    set_blocks = new_icmp_blocks - icmp_blocks
    remove_blocks = icmp_blocks - new_icmp_blocks

    # See the note on interfaces= above: --add-icmp-block and
    # --remove-icmp-block must not be combined in a single firewall-cmd
    # invocation.
    Array(remove_blocks).each { |block| debug("removing block #{block} from zone #{@resource[:name]}") }
    execute_firewall_cmd(batch_flag('--remove-icmp-block', remove_blocks), @resource[:name]) unless remove_blocks.empty?

    Array(set_blocks).each { |block| debug("adding block #{block} to zone #{@resource[:name]}") }
    execute_firewall_cmd(batch_flag('--add-icmp-block', set_blocks), @resource[:name]) unless set_blocks.empty?
  end

  def icmp_block_inversion
    if execute_firewall_cmd(['--query-icmp-block-inversion'], @resource[:name], true, false).chomp == 'yes'
      :true
    else
      :false
    end
  end

  def icmp_block_inversion=(bool)
    case bool
    when :true
      debug("adding icmp block inversion for zone #{@resource[:name]}")
      execute_firewall_cmd(['--add-icmp-block-inversion'], @resource[:name])
    when :false
      debug("removing icmp block inversion for zone #{@resource[:name]}")
      execute_firewall_cmd(['--remove-icmp-block-inversion'], @resource[:name])
    end
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_rules
    perm = execute_firewall_cmd(['--list-rich-rules']).split(%r{\n})
    curr = execute_firewall_cmd(['--list-rich-rules'], @resource[:name], false).split(%r{\n})
    [perm, curr].flatten.uniq
  end

  def get_services
    perm = execute_firewall_cmd(['--list-services']).split
    curr = execute_firewall_cmd(['--list-services'], @resource[:name], false).split
    [perm, curr].flatten.uniq
  end

  def get_ports
    perm = execute_firewall_cmd(['--list-ports']).split
    curr = execute_firewall_cmd(['--list-ports'], @resource[:name], false).split

    [perm, curr].flatten.uniq.map do |entry|
      port, protocol = entry.split(%r{/})
      debug("get_ports() Found port #{port} protocol #{protocol}")
      { 'port' => port, 'protocol' => protocol }
    end
  end

  def get_icmp_blocks
    execute_firewall_cmd(['--list-icmp-blocks'], @resource[:name]).split.sort
  end

  def get_icmp_types
    execute_firewall_cmd(['--get-icmptypes'], nil).split
  end
  # rubocop:enable Naming/AccessorMethodName

  def description
    execute_firewall_cmd(['--get-description'], @resource[:name], true, false)
  end

  def description=(new_description)
    execute_firewall_cmd(['--set-description', new_description], @resource[:name], true, false)
  end

  def short
    execute_firewall_cmd(['--get-short'], @resource[:name], true, false)
  end

  def short=(new_short)
    execute_firewall_cmd(['--set-short', new_short], @resource[:name], true, false)
  end

  def flush
    reload_firewall
  end
end
