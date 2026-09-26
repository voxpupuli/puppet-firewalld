# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_zone).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  # Bulk-load all zone state in a single `firewall-cmd --list-all-zones`
  # invocation. The parsed result is cached on Puppet::Provider::Firewalld
  # so that subsequent resources processed in the same Puppet transaction
  # do not re-shell. reload_firewall invalidates this cache.
  def self.prefetched_zones
    Puppet::Provider::Firewalld.catalog_cache[:zones] ||= begin
      raw = execute_firewall_cmd(['--list-all-zones'], nil)
      text = raw.respond_to?(:to_str) ? raw.to_str : raw.to_s
      Puppet::Provider::Firewalld.parse_list_all_output(text)
    end
  end

  # Translate a single parsed zone Hash (from parse_list_all_output) into
  # a @property_hash suitable for seeding a provider instance.
  def self.property_hash_from_parsed(name, parsed)
    hash = { ensure: :present, name: name }
    hash[:target] = parsed['target'] if parsed.key?('target')
    hash[:interfaces] = parsed['interfaces'].to_s.split if parsed.key?('interfaces')
    hash[:sources]    = parsed['sources'].to_s.split.sort if parsed.key?('sources')
    hash[:protocols]  = parsed['protocols'].to_s.split.sort if parsed.key?('protocols')
    if parsed.key?('masquerade')
      hash[:masquerade] = (parsed['masquerade'].to_s.strip == 'yes') ? :true : :false
    end
    if parsed.key?('icmp-block-inversion')
      hash[:icmp_block_inversion] = (parsed['icmp-block-inversion'].to_s.strip == 'yes') ? :true : :false
    end
    hash[:icmp_blocks] = parsed['icmp-blocks'].to_s.split.sort if parsed.key?('icmp-blocks')
    hash[:description] = parsed['description'] if parsed.key?('description')
    hash[:short]       = parsed['short']       if parsed.key?('short')
    hash
  end

  def self.instances
    prefetched_zones.map do |name, parsed|
      new(property_hash_from_parsed(name, parsed))
    end
  end

  def self.prefetch(resources)
    zones = prefetched_zones
    resources.each do |name, resource|
      next unless zones.key?(name)

      resource.provider = new(property_hash_from_parsed(name, zones[name]))
    end
  end

  # Was this provider instance seeded from a bulk prefetch?  Used by
  # getters to decide whether to trust @property_hash or fall back to a
  # per-property shell-out (the latter is needed when a zone was created
  # mid-run, after prefetch).
  def prefetched?
    !@property_hash.nil? && !@property_hash.empty?
  end

  def exists?
    @resource[:zone] = @resource[:name]
    return @property_hash[:ensure] == :present if prefetched?

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

    # Newly-created zones invalidate the bulk cache so that downstream
    # resources (e.g. another zone in the same run) see consistent state.
    Puppet::Provider::Firewalld.invalidate_cache!(:zones)
    @property_hash[:ensure] = :present
  end

  def destroy
    debug("Deleting zone #{@resource[:name]}")
    execute_firewall_cmd(['--delete-zone', @resource[:name]], nil)
    Puppet::Provider::Firewalld.invalidate_cache!(:zones)
    @property_hash[:ensure] = :absent
  end

  def target
    zone_target = if prefetched? && @property_hash.key?(:target)
                    @property_hash[:target]
                  else
                    execute_firewall_cmd(['--get-target']).chomp
                  end
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
    return @property_hash[:interfaces] || [] if prefetched? && @property_hash.key?(:interfaces)

    execute_firewall_cmd(['--list-interfaces']).chomp.split || []
  end

  def interfaces=(new_interfaces)
    new_interfaces ||= []
    cur_interfaces = interfaces
    (new_interfaces - cur_interfaces).each do |missing_interface|
      debug("Adding interface '#{missing_interface}' to zone #{@resource[:name]}")
      execute_firewall_cmd(['--add-interface', missing_interface])
    end
    (cur_interfaces - new_interfaces).each do |extraneous_interface|
      debug("Removing interface '#{extraneous_interface}' from zone #{@resource[:name]}")
      execute_firewall_cmd(['--remove-interface', extraneous_interface])
    end
  end

  def sources
    return @property_hash[:sources] || [] if prefetched? && @property_hash.key?(:sources)

    execute_firewall_cmd(['--list-sources']).chomp.split.sort || []
  end

  def sources=(new_sources)
    new_sources ||= []
    cur_sources = sources
    (new_sources - cur_sources).each do |missing_source|
      debug("Adding source '#{missing_source}' to zone #{@resource[:name]}")
      execute_firewall_cmd(['--add-source', missing_source])
    end
    (cur_sources - new_sources).each do |extraneous_source|
      debug("Removing source '#{extraneous_source}' from zone #{@resource[:name]}")
      execute_firewall_cmd(['--remove-source', extraneous_source])
    end
  end

  def protocols
    return @property_hash[:protocols] || [] if prefetched? && @property_hash.key?(:protocols)

    execute_firewall_cmd(['--list-protocols']).chomp.split.sort || []
  end

  def protocols=(new_protocols)
    new_protocols ||= []
    cur_protocols = protocols
    (new_protocols - cur_protocols).each do |p|
      debug("Adding protocol '#{p}' to zone #{@resource[:name]}")
      execute_firewall_cmd(['--add-protocol', p])
    end
    (cur_protocols - new_protocols).each do |p|
      debug("Removing protocol '#{p}' from zone #{@resource[:name]}")
      execute_firewall_cmd(['--remove-protocol', p])
    end
  end

  def masquerade
    return @property_hash[:masquerade] if prefetched? && @property_hash.key?(:masquerade)

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
    return @property_hash[:icmp_blocks] || [] if prefetched? && @property_hash.key?(:icmp_blocks)

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

    Array(remove_blocks).each do |block|
      debug("removing block #{block} from zone #{@resource[:name]}")
      execute_firewall_cmd(['--remove-icmp-block', block], @resource[:name])
    end
    Array(set_blocks).each do |block|
      debug("adding block #{new_icmp_blocks} to zone #{@resource[:name]}")
      execute_firewall_cmd(['--add-icmp-block', block], @resource[:name])
    end
  end

  def icmp_block_inversion
    return @property_hash[:icmp_block_inversion] if prefetched? && @property_hash.key?(:icmp_block_inversion)

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
    return @property_hash[:description] if prefetched? && @property_hash.key?(:description)

    execute_firewall_cmd(['--get-description'], @resource[:name], true, false)
  end

  def description=(new_description)
    execute_firewall_cmd(['--set-description', new_description], @resource[:name], true, false)
  end

  def short
    return @property_hash[:short] if prefetched? && @property_hash.key?(:short)

    execute_firewall_cmd(['--get-short'], @resource[:name], true, false)
  end

  def short=(new_short)
    execute_firewall_cmd(['--set-short', new_short], @resource[:name], true, false)
  end

  def flush
    reload_firewall
  end
end
