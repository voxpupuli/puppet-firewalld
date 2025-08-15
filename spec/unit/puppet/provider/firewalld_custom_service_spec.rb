# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_custom_service).provider(:firewall_cmd)

describe provider_class do
  require 'rexml/document'
  include REXML

  before do
    allow_any_instance_of(provider_class).to receive(:execute_firewall_cmd).and_return(double(exitstatus: 0))
  end

  let(:provider) { resource.provider }

  context 'simplest resource creation' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :present,
        name: 'test_service'
      )
    end

    it 'creates the service' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--new-service', resource[:name]], nil)
      provider.create
    end

    it 'retrieves and formats the system ports' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--get-ports'], nil).and_return('123/tcp 456/udp')

      expect(provider.ports).to eq([
                                     {
                                       'port' => '123',
                                       'protocol' => 'tcp'
                                     },
                                     {
                                       'port' => '456',
                                       'protocol' => 'udp'
                                     }
                                   ])
    end

    it 'retrieves and formats the system destinations' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--get-destinations'], nil).and_return('ipv4:1.2.3.4/23 ipv6:::1')

      expect(provider.ipv4_destination).to eq('1.2.3.4/23')
      expect(provider.ipv6_destination).to eq('::1')
    end

    it 'exists when returned by the system' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return("#{resource[:name]} foo bar baz")
      expect(provider).to receive(:execute_firewall_cmd).with(['--path-service', resource[:name]], nil).and_return('/etc/foo_bar_baz.xml')

      expect(provider.exists?).to be true
    end

    it 'does not exist when not returned by the system' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return('foo bar baz')

      expect(provider.exists?).to be false
    end
  end

  context 'resource deletion' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :absent,
        name: 'test_service'
      )
    end

    it 'runs delete-service when it is not a builtin' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--delete-service', resource[:name]], nil)
      provider.destroy
    end

    it 'runs load-service-defaults when it is a builtin' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--delete-service', resource[:name]], nil).and_raise(Puppet::ExecutionFailure, 'nooooooooooooo')
      expect(provider).to receive(:execute_firewall_cmd).with(['--load-service-default', resource[:name]], nil)

      provider.destroy
    end
  end

  context 'all parameters populated' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :present,
        name: 'test_service',
        short: 'Short Name',
        description: 'This is a description',
        ports: [
          '123/tcp',
          '234/udp',
          { 'port' => 345, 'protocol' => 'udp' },
          { 'port' => '456', 'protocol' => 'tcp' },
          { 'protocol' => 'dccp' }
        ],
        protocols: %w[foo bar baz],
        modules: %w[nf_thingy nf_other_thingy],
        ipv4_destination: '1.2.3.0/24',
        ipv6_destination: '::1'
      )
    end

    it 'creates the service' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--new-service', resource[:name]], nil)
      expect(provider).to receive(:short=).with(resource[:short])
      expect(provider).to receive(:description=).with(resource[:description])
      expect(provider).to receive(:ports).and_return(true)
      expect(provider).to receive(:ports=).with(resource[:ports])
      expect(provider).to receive(:protocols).and_return(true)
      expect(provider).to receive(:protocols=).with(resource[:protocols])
      expect(provider).to receive(:modules).and_return(true)
      expect(provider).to receive(:modules=).with(resource[:modules])
      expect(provider).to receive(:ipv4_destination=).with(resource[:ipv4_destination])
      expect(provider).to receive(:ipv6_destination=).with(resource[:ipv6_destination])

      provider.create
    end

    it 'sets the short description' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-short', resource[:short]], nil)
      provider.short = resource[:short]
    end

    it 'sets the full description' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-description', resource[:description]], nil)
      provider.description = resource[:description]
    end

    context 'setting ports' do
      it 'works without existing ports' do
        [
          '123/tcp',
          '234/udp',
          '345/udp',
          '456/tcp'
        ].each do |port|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-port', port], nil)
        end

        ports = []
        provider.instance_variable_set('@property_hash', ports: ports)
        provider.ports = resource[:ports]
      end

      it 'works with disjoint existing ports' do
        [
          '123/tcp',
          '234/udp',
          '345/udp',
          '456/tcp'
        ].each do |port|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-port', port], nil)
        end

        ports = [
          { 'port' => '789', 'protocol' => 'udp' },
          { 'port' => '8910', 'protocol' => 'tcp' }
        ]
        provider.instance_variable_set('@property_hash', ports: ports)

        [
          '789/udp',
          '8910/tcp'
        ].each do |port|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-port', port], nil)
        end

        provider.ports = resource[:ports]
      end

      it 'works with overlapping existing ports' do
        [
          '123/tcp',
          '234/udp',
          '456/tcp'
        ].each do |port|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-port', port], nil)
        end

        ports = [
          { 'port' => '345', 'protocol' => 'udp' },
          { 'port' => '8910', 'protocol' => 'tcp' }
        ]
        provider.instance_variable_set('@property_hash', ports: ports)

        [
          '8910/tcp'
        ].each do |port|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-port', port], nil)
        end

        provider.ports = resource[:ports]
      end
    end

    context 'setting protocols' do
      it 'works without existing protocols' do
        %w[
          foo
          bar
          baz
          dccp
        ].each do |protocol|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-protocol', protocol], nil)
        end

        protocols = []
        provider.instance_variable_set('@property_hash', protocols: protocols)
        provider.protocols = resource[:protocols]
      end

      it 'works with disjoint existing protocols' do
        %w[
          foo
          bar
          baz
          dccp
        ].each do |protocol|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-protocol', protocol], nil)
        end

        protocols = %w[
          icmp
          test
        ]
        provider.instance_variable_set('@property_hash', protocols: protocols)

        protocols.each do |protocol|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-protocol', protocol], nil)
        end

        provider.protocols = resource[:protocols]
      end

      it 'works with overlapping existing protocols' do
        %w[
          foo
          baz
          dccp
        ].each do |protocol|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-protocol', protocol], nil)
        end

        protocols = %w[
          bar
          icmp
        ]
        provider.instance_variable_set('@property_hash', protocols: protocols)

        ['icmp'].each do |protocol|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-protocol', protocol], nil)
        end

        provider.protocols = resource[:protocols]
      end
    end

    context 'setting modules' do
      it 'works without existing modules' do
        %w[
          nf_thingy
          nf_other_thingy
        ].each do |mod|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-module', mod], nil)
        end

        modules = []
        provider.instance_variable_set('@property_hash', modules: modules)
        provider.modules = resource[:modules]
      end

      it 'works with disjoint existing modules' do
        %w[
          nf_thingy
          nf_other_thingy
        ].each do |mod|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-module', mod], nil)
        end

        modules = %w[
          nf_stuff
          nf_bob
        ]
        provider.instance_variable_set('@property_hash', modules: modules)

        modules.each do |mod|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-module', mod], nil)
        end

        provider.modules = resource[:modules]
      end

      it 'works with overlapping existing modules' do
        [
          'nf_other_thingy'
        ].each do |mod|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-module', mod], nil)
        end

        modules = %w[
          nf_thingy
          nf_bob
        ]
        provider.instance_variable_set('@property_hash', modules: modules)

        ['nf_bob'].each do |mod|
          expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-module', mod], nil)
        end

        provider.modules = resource[:modules]
      end
    end

    it 'sets the ipv4_destination' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-destination', "ipv4:#{resource[:ipv4_destination]}"], nil)
      provider.ipv4_destination = resource[:ipv4_destination]
    end

    it 'sets the ipv6_destination' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-destination', "ipv6:#{resource[:ipv6_destination]}"], nil)
      provider.ipv6_destination = resource[:ipv6_destination]
    end
  end
end
