# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_custom_service).provider(:dbus)

describe provider_class do
  before do
    allow_any_instance_of(Puppet::Provider::FirewalldDbus).to receive(:version?).and_return(true)
    allow_any_instance_of(provider_class).to receive(:dbus_connection).and_raise(NotImplementedError)
    allow_any_instance_of(provider_class).to receive(:reload_firewall)
  end

  let(:provider) { resource.provider }

  context 'simplest resource creation' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :present,
        name: 'test_service',
        provider: :dbus,
      )
    end

    it 'creates the service' do
      allow(provider).to receive(:dbus_resource_settings).and_return({})
      expect(provider).to receive(:create_custom_service).with(resource[:name], {})
      provider.create
    end

    it 'retrieves and formats the system ports' do
      expect(provider).to receive(:dbus_resource_settings).and_return({
        'ports' => [
          ['123', 'tcp'],
          ['456', 'udp']
        ]
      })

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
      allow(provider).to receive(:dbus_resource_settings).and_return({
        'destination' => {
          'ipv4' => '1.2.3.4/23',
          'ipv6' => '::1'
        }
      })

      expect(provider.ipv4_destination).to eq('1.2.3.4/23')
      expect(provider.ipv6_destination).to eq('::1')
    end

    it 'exists when custom' do
      service = double()
      allow(service).to receive(:[]).with('builtin').and_return(false)
      allow(provider).to receive(:dbus_resource).and_return(service)

      expect(provider.exists?).to be true
    end

    it 'exists when builtin' do
      service = double()
      allow(service).to receive(:[]).with('builtin').and_return(true)
      allow(provider).to receive(:dbus_resource).and_return(service)

      expect(provider.exists?).to be true
    end

    it 'does not exist when builtin and ensure => :absent' do
      service = double()
      allow(service).to receive(:[]).with('builtin').and_return(true)
      allow(provider).to receive(:dbus_resource).and_return(service)

      provider.instance_variable_get(:@resource)[:ensure] = :absent

      expect(provider.exists?).to be false
    end
  end

  context 'resource deletion' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :absent,
        name: 'test_service',
        provider: :dbus,
      )
    end

    it 'runs delete-service when it is not a builtin' do
      service = double()
      allow(service).to receive(:[]).with('builtin').and_return(false)
      allow(provider).to receive(:dbus_resource).and_return(service)

      expect(service).to receive(:remove)
      expect(service).to_not receive(:loadDefaults)
      provider.destroy
    end

    it 'runs load-service-defaults when it is a builtin' do
      service = double()
      allow(service).to receive(:[]).with('builtin').and_return(true)
      allow(provider).to receive(:dbus_resource).and_return(service)

      expect(service).to_not receive(:remove)
      expect(service).to receive(:loadDefaults)

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
        ipv6_destination: '::1',
        provider: :dbus,
      )
    end

    it 'creates the service' do
      allow(provider).to receive(:dbus_resource_settings).and_return({})
      expect(provider).to receive(:create_custom_service).with(resource[:name], {
        'short' => resource[:short],
        'description' => resource[:description],
        'ports' => [
          ['123', 'tcp'],
          ['234', 'udp'],
          ['345', 'udp'],
          ['456', 'tcp'],
          ['', 'dccp']
        ],
        'protocols' => resource[:protocols],
        'modules' => resource[:modules],
        'destination' => {
          'ipv4' => resource[:ipv4_destination],
          'ipv6' => resource[:ipv6_destination],
        }
      })

      provider.create
    end

    it 'sets the short description' do
      provider.short = resource[:short]

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'short' => resource[:short] })
      provider.flush
    end

    it 'unsets the short description' do
      provider.short = nil

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'short' => '' })
      provider.flush
    end

    it 'sets the full description' do
      provider.description = resource[:description]

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'description' => resource[:description] })
      provider.flush
    end

    it 'unsets the full description' do
      provider.description = nil

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'description' => '' })
      provider.flush
    end

    it 'sets the full port list' do
      provider.ports = resource[:ports]

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'ports' => [
        ['123', 'tcp'],
        ['234', 'udp'],
        ['345', 'udp'],
        ['456', 'tcp'],
        ['', 'dccp']
      ] })
      provider.flush
    end

    it 'unsets the full port list' do
      provider.ports = nil

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'ports' => [] })
      provider.flush
    end

    it 'sets the full protocol list' do
      provider.protocols = resource[:protocols]

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'protocols' => resource[:protocols] })
      provider.flush
    end

    it 'unsets the full protocol list' do
      provider.protocols = nil

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'protocols' => [] })
      provider.flush
    end

    it 'sets the full module list' do
      provider.modules = resource[:modules]

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'modules' => resource[:modules] })
      provider.flush
    end

    it 'unsets the full module list' do
      provider.modules = nil

      allow(provider).to receive(:reload_firewall)
      expect(provider).to receive(:dbus_update_resource_settings).with({ 'modules' => [] })
      provider.flush
    end

    context 'destination' do
      it 'keeps the ipv6 destination when setting the ipv4_destination' do
        allow(provider).to receive(:dbus_resource_settings).and_return({ 'destination' => { 'ipv6' => resource[:ipv6_destination] }})
        expect(provider).to receive(:dbus_update_resource_settings).with({ 'destination' => { 'ipv4' => resource[:ipv4_destination], 'ipv6' => resource[:ipv6_destination] }})
        provider.ipv4_destination = resource[:ipv4_destination]
        provider.flush
      end

      it 'keeps the ipv4 destination when setting the ipv6_destination' do
        allow(provider).to receive(:dbus_resource_settings).and_return({ 'destination' => { 'ipv4' => resource[:ipv4_destination] }})
        expect(provider).to receive(:dbus_update_resource_settings).with({ 'destination' => { 'ipv4' => resource[:ipv4_destination], 'ipv6' => resource[:ipv6_destination] }})
        provider.ipv6_destination = resource[:ipv6_destination]
        provider.flush
      end

      it 'sets both destinations when both have been provided' do
        allow(provider).to receive(:dbus_resource_settings).and_return({})
        expect(provider).to receive(:dbus_update_resource_settings).with({ 'destination' => { 'ipv4' => resource[:ipv4_destination], 'ipv6' => resource[:ipv6_destination] }})
        provider.ipv4_destination = resource[:ipv4_destination]
        provider.ipv6_destination = resource[:ipv6_destination]
        provider.flush
      end

      it 'clears the destination list when set to undef' do
        allow(provider).to receive(:dbus_resource_settings).and_return({ 'destination' => { 'ipv4' => resource[:ipv4_destination], 'ipv6' => resource[:ipv6_destination] } })
        expect(provider).to receive(:dbus_update_resource_settings).with({ 'destination' => {} })
        provider.ipv4_destination = nil
        provider.ipv6_destination = nil
        provider.flush
      end
    end
  end
end
