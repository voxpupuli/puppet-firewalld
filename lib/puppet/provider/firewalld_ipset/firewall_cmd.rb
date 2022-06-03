# frozen_string_literal: true

require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_ipset).provide(
  :firewall_cmd,
  parent: Puppet::Provider::Firewalld
) do
  desc 'Interact with firewall-cmd'

  mk_resource_methods

  def self.instances
    ipset_ids = execute_firewall_cmd(['--get-ipsets'], nil).split
    ipset_ids.map do |ipset_id|
      ipset_raw = execute_firewall_cmd(["--info-ipset=#{ipset_id}"], nil)
      raw_options = ipset_raw.match(%r{options: (.*)})
      options = {}
      if raw_options
        raw_options[1].split.each do |v|
          k, v = v.split('=')
          options[k.to_sym] = v
        end
      end
      new(
        {
          ensure: :present,
          name: ipset_id,
          type: ipset_raw.match(%r{type: (.*)})[1]
        }.merge(options)
      )
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    args = []
    args << ["--new-ipset=#{@resource[:name]}"]
    args << ["--type=#{@resource[:type]}"]
    options = {
      family: @resource[:family],
      hashsize: @resource[:hashsize],
      maxelem: @resource[:maxelem],
      timeout: @resource[:timeout]
    }
    options = options.merge(@resource[:options]) if @resource[:options]
    options.each do |option_name, value|
      args << ["--option=#{option_name}=#{value}"] if value
    end
    execute_firewall_cmd(args.flatten, nil)
    @resource[:entries].each { |e| add_entry(e) } if @resource[:manage_entries]
  end

  %i[type maxelem family hashsize timeout].each do |method|
    define_method("#{method}=") do |should|
      info("Destroying and creating ipset #{@resource[:name]}")
      destroy
      create
      @property_hash[method] = should
    end
  end

  def entries
    if @resource[:manage_entries]
      execute_firewall_cmd(["--ipset=#{@resource[:name]}", '--get-entries'], nil).split("\n").sort
    else
      @resource[:entries]
    end
  end

  def add_entry(entry)
    execute_firewall_cmd(["--ipset=#{@resource[:name]}", "--add-entry=#{entry}"], nil)
  end

  def remove_entry(entry)
    execute_firewall_cmd(["--ipset=#{@resource[:name]}", "--remove-entry=#{entry}"], nil)
  end

  def entries=(should_entries)
    unless @resource[:manage_entries]
      debug("Not managing entries for ipset #{@resource[:name]}")
      return
    end
    cur_entries = entries
    delete_entries = cur_entries - should_entries
    add_entries = should_entries - cur_entries
    delete_entries.each { |e| remove_entry(e) }
    add_entries.each { |e| add_entry(e) }
  end

  def destroy
    execute_firewall_cmd(["--delete-ipset=#{@resource[:name]}"], nil)
  end
end
