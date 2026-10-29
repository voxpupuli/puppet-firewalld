# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_custom_service).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld,
) do
  desc 'Interact with firewall-cmd'

  mk_resource_methods

  # Lists every known service name (predefined + custom) with a single
  # firewall-cmd invocation. Note this is the same --get-services catalog
  # firewalld_service's instances mistakenly used to rely on; it's correct
  # to use here because firewalld_custom_service really is asking "does a
  # service definition with this name exist at all", not "is this service
  # bound to a zone".
  #
  # Deliberately not memoized across calls: firewalld's state can change
  # between Puppet runs (and even within long-lived processes such as a
  # puppetserver or an rspec suite), so each call to prefetch must re-fetch.
  #
  def self.all_service_names
    execute_firewall_cmd(['--get-services'], nil).strip.split
  end

  def self.instances
    all_service_names.map { |s| new(ensure: :present, name: s) }
  end

  # firewalld_custom_service's namevar maps directly to the firewalld
  # service name (unlike firewalld_service, where the Puppet title and the
  # firewalld-level name can differ), so resources can safely be matched by
  # name. --path-service still requires one shellout per resource actually
  # found, since firewalld has no bulk "which of these are builtin" query;
  # that call is only made when needed, same as before.
  #
  def self.prefetch(resources)
    names = all_service_names

    resources.each_value do |resource|
      builtin = true
      found_resource = names.include?(resource[:name])
      builtin = false if found_resource && execute_firewall_cmd(['--path-service', resource[:name]], nil).start_with?('/etc')

      present = found_resource
      present = false if builtin && resource[:ensure] == :absent

      resource.provider = new(ensure: present ? :present : :absent, name: resource[:name])
    end
  end

  # If this instance went through self.prefetch, @property_hash[:ensure] is
  # already known and no shellout is needed. Resources built outside the
  # normal catalog/prefetch flow have no prefetched state, so fall back to a
  # live query for those.
  def exists?
    return @property_hash[:ensure] == :present if @property_hash.key?(:ensure)

    builtin = true

    found_resource = execute_firewall_cmd(['--get-services'], nil).strip.split.include?(@resource[:name])

    builtin = false if found_resource && execute_firewall_cmd(['--path-service', @resource[:name]], nil).start_with?('/etc')

    return false if builtin && (@resource[:ensure] == :absent)

    found_resource
  end

  def create
    debug("Adding new custom service to firewalld: #{@resource[:name]}")
    execute_firewall_cmd(['--new-service', @resource[:name]], nil)

    send(:short=, @resource[:short]) if @resource[:short]
    send(:description=, @resource[:description]) if @resource[:description]
    ports && send(:ports=, @resource[:ports]) unless @resource[:ports].include?(:unset)
    protocols && send(:protocols=, @resource[:protocols]) unless @resource[:protocols].include?(:unset)
    modules && send(:modules=, @resource[:modules]) unless @resource[:modules].include?(:unset)
    send(:ipv4_destination=, @resource[:ipv4_destination]) unless @resource[:ipv4_destination] == :unset
    send(:ipv6_destination=, @resource[:ipv6_destination]) unless @resource[:ipv6_destination] == :unset
  end

  def destroy
    execute_firewall_cmd(['--delete-service', @resource[:name]], nil)
  rescue Puppet::ExecutionFailure
    execute_firewall_cmd(['--load-service-default', @resource[:name]], nil)
  end

  def short
    execute_firewall_cmd(['--service', @resource[:name], '--get-short'], nil).strip
  end

  def short=(should)
    execute_firewall_cmd(['--service', @resource[:name], '--set-short', should], nil)
  end

  def description
    execute_firewall_cmd(['--service', @resource[:name], '--get-description'], nil).strip
  end

  def description=(should)
    execute_firewall_cmd(['--service', @resource[:name], '--set-description', should], nil)
  end

  def ports
    @property_hash[:ports] = execute_firewall_cmd(['--service', @resource[:name], '--get-ports'], nil).strip.split(%r{\s+}).map do |entry|
      port, proto = entry.strip.split('/')
      { 'port' => port, 'protocol' => proto }
    end

    @property_hash[:ports]
  end

  # NOTE: --add-port and --remove-port must never be combined in a single
  # firewall-cmd invocation: firewall-cmd's argument parsing only acts on
  # the first recognized action flag it sees, so a mixed call would
  # silently drop everything after it. Repeating the same flag for multiple
  # values is fine and is what collapses N calls into one here. Because
  # that means we can no longer isolate which individual port failed,
  # add/remove failures are now reported per-batch rather than per-port.
  def ports=(should)
    to_add = []
    to_remove = []

    if Array(should).include?(:unset)
      to_remove = @property_hash[:ports]
    else
      to_remove = @property_hash[:ports] - should
      to_add = should - @property_hash[:ports]
    end

    # Protocols could have been specified in there
    add_strs = to_add.select { |entry| entry['port'] }.map { |entry| "#{entry['port']}/#{entry['protocol']}" }
    remove_strs = to_remove.map { |entry| "#{entry['port']}/#{entry['protocol']}" }

    errors = []
    begin
      execute_firewall_cmd(['--service', @resource[:name]] + batch_flag('--add-port', add_strs), nil) unless add_strs.empty?
    rescue Puppet::ExecutionFailure => e
      errors << "Could not add port(s) '#{add_strs.join(', ')}' to #{@resource[:name]} => #{e}"
    end

    begin
      execute_firewall_cmd(['--service', @resource[:name]] + batch_flag('--remove-port', remove_strs), nil) unless remove_strs.empty?
    rescue Puppet::ExecutionFailure => e
      errors << "Could not remove port(s) '#{remove_strs.join(', ')}' from #{@resource[:name]} => #{e}"
    end

    raise Puppet::ResourceError, errors.join("\n") unless errors.empty?
  end

  def protocols
    @property_hash[:protocols] = execute_firewall_cmd(['--service', @resource[:name], '--get-protocols'], nil).strip.split(%r{\s+})

    @property_hash[:protocols]
  end

  # See the note on ports= above: --add-protocol and --remove-protocol must
  # not be combined in a single firewall-cmd invocation.
  def protocols=(should)
    to_add = []
    to_remove = []

    if Array(should).include?(:unset)
      to_remove = @property_hash[:protocols]
    else
      to_remove = @property_hash[:protocols] - should
      ports_protos = []
      ports_protos = Array(@resource[:ports]).select { |x| x['port'].nil? }.map { |x| x['protocol'] } unless @resource[:ports].include?(:unset)
      to_add = (should + ports_protos) - @property_hash[:protocols]
    end

    errors = []
    begin
      execute_firewall_cmd(['--service', @resource[:name]] + batch_flag('--add-protocol', to_add), nil) unless to_add.empty?
    rescue Puppet::ExecutionFailure => e
      errors << "Could not add protocol(s) '#{to_add.join(', ')}' to #{@resource[:name]} => #{e}"
    end

    begin
      execute_firewall_cmd(['--service', @resource[:name]] + batch_flag('--remove-protocol', to_remove), nil) unless to_remove.empty?
    rescue Puppet::ExecutionFailure => e
      errors << "Could not remove protocol(s) '#{to_remove.join(', ')}' from #{@resource[:name]} => #{e}"
    end

    raise Puppet::ResourceError, errors.join("\n") unless errors.empty?
  end

  def modules
    @property_hash[:modules] = execute_firewall_cmd(['--service', @resource[:name], '--get-modules'], nil).strip.split(%r{\s+})

    @property_hash[:modules]
  end

  # See the note on ports= above: --add-module and --remove-module must not
  # be combined in a single firewall-cmd invocation.
  def modules=(should)
    to_add = []
    to_remove = []

    if Array(should).include?(:unset)
      to_remove = @property_hash[:modules]
    else
      to_remove = @property_hash[:modules] - should
      to_add = should - @property_hash[:modules]
    end

    errors = []
    begin
      execute_firewall_cmd(['--service', @resource[:name]] + batch_flag('--add-module', to_add), nil) unless to_add.empty?
    rescue Puppet::ExecutionFailure => e
      errors << "Could not add module(s) '#{to_add.join(', ')}' to #{@resource[:name]} => #{e}"
    end

    begin
      execute_firewall_cmd(['--service', @resource[:name]] + batch_flag('--remove-module', to_remove), nil) unless to_remove.empty?
    rescue Puppet::ExecutionFailure => e
      errors << "Could not remove module(s) '#{to_remove.join(', ')}' from #{@resource[:name]} => #{e}"
    end

    raise Puppet::ResourceError, errors.join("\n") unless errors.empty?
  end

  def ipv4_destination
    @property_hash[:ipv4_destination] = destinations['ipv4']
    @property_hash[:ipv4_destination] ||= ''

    @property_hash[:ipv4_destination]
  end

  def ipv4_destination=(should)
    if should == :unset
      execute_firewall_cmd(['--service', @resource[:name], '--remove-destination', 'ipv4'], nil) unless @property_hash[:ipv4_destination].empty?
    else
      execute_firewall_cmd(['--service', @resource[:name], '--set-destination', "ipv4:#{should}"], nil)
    end
  end

  def ipv6_destination
    @property_hash[:ipv6_destination] = destinations['ipv6']
    @property_hash[:ipv6_destination] ||= ''

    @property_hash[:ipv6_destination]
  end

  def ipv6_destination=(should)
    if should == :unset
      execute_firewall_cmd(['--service', @resource[:name], '--remove-destination', 'ipv6'], nil) unless @property_hash[:ipv6_destination].empty?
    else
      execute_firewall_cmd(['--service', @resource[:name], '--set-destination', "ipv6:#{should}"], nil)
    end
  end

  def flush
    reload_firewall
  end

  private

  # Return a Hash of destinations
  #
  # @example IPv4 and IPv6 destinations
  #
  #   { 'ipv4' => '1.2.3.0/24', 'ipv6' => '::1' }
  #
  # @return [Hash[String,String]]
  def destinations
    return @destinations if @destinations

    @destinations = execute_firewall_cmd(['--service', @resource[:name], '--get-destinations'], nil).strip.split(%r{\s+})
    @destinations = @destinations.to_h { |x| x.split(':', 2) }

    @destinations
  end
end
