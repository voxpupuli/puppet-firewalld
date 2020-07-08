require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_custom_service).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  mk_resource_methods

  def exists?
    builtin = true

    found_resource = execute_firewall_cmd(['--get-services'], nil).strip.split(' ').include?(@resource[:name])

    if found_resource && execute_firewall_cmd(['--path-service', @resource[:name]], nil).start_with?('/etc')
      builtin = false
    end

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

  def ports=(should)
    to_add = []
    to_remove = []

    if Array(should).include?(:unset)
      to_remove = @property_hash[:ports]
    else
      to_remove = @property_hash[:ports] - should
      to_add = should - @property_hash[:ports]
    end

    errors = []
    to_add.each do |entry|
      # Protocols could have been specified in there
      next unless entry['port']

      begin
        port_str = "#{entry['port']}/#{entry['protocol']}"

        execute_firewall_cmd(['--service', @resource[:name], '--add-port', port_str], nil)
      rescue Puppet::ExecutionFailure => e
        errors << "Could not add port '#{port_str} to #{@resource[:name]}' => #{e}"
      end
    end

    to_remove .each do |entry|
      begin
        port_str = "#{entry['port']}/#{entry['protocol']}"

        execute_firewall_cmd(['--service', @resource[:name], '--remove-port', port_str], nil)
      rescue Puppet::ExecutionFailure => e
        errors << "Could not remove port '#{port_str} from #{@resource[:name]}' => #{e}"
      end
    end

    raise Puppet::ResourceError, errors.join("\n") unless errors.empty?
  end

  def protocols
    @property_hash[:protocols] = execute_firewall_cmd(['--service', @resource[:name], '--get-protocols'], nil).strip.split(%r{\s+})

    @property_hash[:protocols]
  end

  def protocols=(should)
    to_add = []
    to_remove = []

    if Array(should).include?(:unset)
      to_remove = @property_hash[:protocols]
    else
      to_remove = @property_hash[:protocols] - should
      to_add = (
        should + Array(@resource[:ports]).select { |x| x['port'].nil? }.map { |x| x['protocol'] }
      ) - @property_hash[:protocols]
    end

    errors = []
    to_add.each do |entry|
      begin
        execute_firewall_cmd(['--service', @resource[:name], '--add-protocol', entry], nil)
      rescue Puppet::ExecutionFailure => e
        errors << "Could not add protocol '#{entry} to #{@resource[:name]}' => #{e}"
      end
    end

    to_remove.each do |entry|
      begin
        execute_firewall_cmd(['--service', @resource[:name], '--remove-protocol', entry], nil)
      rescue Puppet::ExecutionFailure => e
        errors << "Could not remove protocol'#{entry} from #{@resource[:name]}' => #{e}"
      end
    end

    raise Puppet::ResourceError, errors.join("\n") unless errors.empty?
  end

  def modules
    @property_hash[:modules] = execute_firewall_cmd(['--service', @resource[:name], '--get-modules'], nil).strip.split(%r{\s+})

    @property_hash[:modules]
  end

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
    to_add.each do |entry|
      begin
        execute_firewall_cmd(['--service', @resource[:name], '--add-module', entry], nil)
      rescue Puppet::ExecutionFailure => e
        errors << "Could not add module '#{entry} to #{@resource[:name]}' => #{e}"
      end
    end

    to_remove.each do |entry|
      begin
        execute_firewall_cmd(['--service', @resource[:name], '--remove-module', entry], nil)
      rescue Puppet::ExecutionFailure => e
        errors << "Could not remove module '#{entry} from #{@resource[:name]}' => #{e}"
      end
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
    @destinations = Hash[@destinations.map { |x| x.split(':', 2) }]

    @destinations
  end
end
