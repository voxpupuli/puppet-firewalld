# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_zone).provider(:dbus)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_zone).new(
      ensure: :present,
      name: 'internal',
      description: 'Interface for management',
      interfaces: ['eth0'],
      provider: described_class.name
    )
  end
  let(:provider) { resource.provider }

  before do
    @zone_double = double()
    allow(provider).to receive(:dbus_resource).and_return(@zone_double)

    allow(@zone_double).to receive(:[]).with('name')

    @config_interface_double = double()
    allow(Puppet::Provider::FirewalldDbus).to receive(:firewalld_config_interface).and_return(@config_interface_double)
    allow(provider).to receive(:reload_firewall)
  end

  describe 'when creating' do
    context 'with name white' do
      it 'creates new zone' do
        expect(resource).to receive(:[]).with(:name).and_return('white').at_least(:once)
        expect(resource).to receive(:[]).with(:target).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:sources).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:protocols).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:interfaces).and_return(['eth0']).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_blocks).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_block_inversion).and_return(false).at_least(:once)
        expect(resource).to receive(:[]).with(:description).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:short).and_return('little description').at_least(:once)

        expect(described_class).to receive(:dbus_interface).with(object: 'zone', interface: 'org.fedoraproject.FirewallD1.config.zone').and_return(@zone_double)
        expect(@config_interface_double).to receive(:addZone2).with('white', { 'interfaces' => ['eth0'], 'short' => 'little description' }).and_return("zone")

        provider.create
      end
    end
  end

  describe 'when modifying' do
    context 'type' do
      it 'removes and create a new ipset' do
        expect(resource).to receive(:[]).with(:name).and_return('white').at_least(:once)
        expect(resource).to receive(:[]).with(:target).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:sources).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:protocols).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:interfaces).and_return(['eth0']).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_blocks).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_block_inversion).and_return(false).at_least(:once)
        expect(resource).to receive(:[]).with(:description).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:short).and_return('little description').at_least(:once)

        expect(described_class).to receive(:dbus_interface).with(object: 'zone', interface: 'org.fedoraproject.FirewallD1.config.zone').and_return(@zone_double)
        expect(@config_interface_double).to receive(:addZone2).with('white', { 'interfaces' => ['eth0'], 'short' => 'little description' }).and_return("zone")
        provider.create

        expect(@zone_double).to receive(:update2).with({ 'description' => 'Better description' })

        provider.description = 'Better description'
        provider.flush
      end
    end
  end
end
