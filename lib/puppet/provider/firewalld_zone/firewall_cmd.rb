# frozen_string_literal: true

require 'puppet'
require 'puppet/type'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_zone).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  def exists?
    @resource[:zone] = @resource[:name]
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
