# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_zone).provider(:firewall_cmd)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_zone).new(
      ensure: :present,
      name: 'internal',
      description: 'Interface for management',
      interfaces: ['eth0'],
      provider: described_class.name,
    )
  end
  let(:provider) { resource.provider }

  before do
    allow(provider).to receive(:execute_firewall_cmd).and_return(double(exitstatus: 0))
    allow(provider).to receive(:execute_firewall_cmd).with(['--list-interfaces']).and_return(double(exitstatus: 0, chomp: ''))
  end

  describe 'when creating' do
    context 'with name white' do
      it 'executes firewall_cmd with new-zone' do
        expect(resource).to receive(:[]).with(:name).and_return('white').at_least(:once)
        expect(resource).to receive(:[]).with(:target).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:sources).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:protocols).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:interfaces).and_return(['eth0']).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_blocks).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_block_inversion).and_return(false).at_least(:once)
        expect(resource).to receive(:[]).with(:description).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:short).and_return('little description').at_least(:once)
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-interfaces'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-zone', 'white'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--set-short', 'little description'], 'white', true, false)
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-interfaces'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-zone', 'white'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--set-short', 'little description'], 'white', true, false)
        expect(provider).to receive(:execute_firewall_cmd).with(['--set-description', :'Better description'], 'white', true, false)
        provider.create

        provider.description = :'Better description'
      end
    end
  end

  describe 'self.instances' do
    it 'reflects every existing zone' do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--get-zones'], nil).and_return('public work internal')
      expect(provider_class.instances.map(&:name)).to contain_exactly('public', 'work', 'internal')
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by name, since the zone namevar is the zone name itself' do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--get-zones'], nil).and_return('public work')
      zone = Puppet::Type.type(:firewalld_zone).new(name: 'public')

      provider_class.prefetch('public' => zone)

      expect(zone.provider.exists?).to be true
    end

    it 'does not falsely report present for an unconfigured zone' do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--get-zones'], nil).and_return('public work')
      zone = Puppet::Type.type(:firewalld_zone).new(name: 'restricted')

      provider_class.prefetch('restricted' => zone)

      expect(zone.provider.exists?).to be false
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      zone = Puppet::Type.type(:firewalld_zone).new(name: 'public')
      zone.provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(zone.provider).not_to receive(:execute_firewall_cmd)
      expect(zone.provider.exists?).to be true
    end

    it 'falls back to a live query when the resource was never prefetched' do
      zone = Puppet::Type.type(:firewalld_zone).new(name: 'public', ensure: :absent)

      expect(zone.provider).to receive(:execute_firewall_cmd).with(['--get-zones'], nil).and_return('public work')
      expect(zone.provider.exists?).to be true
    end
  end
end
