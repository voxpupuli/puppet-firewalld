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
    # Every test starts with a clean transaction cache so that prefetched
    # state from one example does not leak into another.
    Puppet::Provider::Firewalld.invalidate_cache!
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

  describe 'bulk prefetch' do
    let(:list_all_zones_output) do
      <<~OUTPUT
        public (active)
          target: default
          icmp-block-inversion: no
          interfaces: eth0
          sources:
          services: ssh dhcpv6-client
          ports:
          protocols:
          masquerade: no
          forward-ports:
          source-ports:
          icmp-blocks:
          rich rules:
          description: Public zone
          short: Public

        internal (active)
          target: ACCEPT
          icmp-block-inversion: yes
          interfaces: eth1 eth2
          sources: 192.168.1.0/24
          protocols: icmp
          masquerade: yes
          icmp-blocks: echo-request echo-reply
          description: Internal zone
          short: Internal
      OUTPUT
    end

    before do
      # Stub the bulk-prefetch shell-out to return our canned fixture.
      # Using the class-level method matches what prefetch() actually
      # invokes.
      allow(described_class).to receive(:execute_firewall_cmd).with(['--list-all-zones'], nil).and_return(list_all_zones_output)
    end

    after do
      Puppet::Provider::Firewalld.invalidate_cache!
    end

    it 'parses zone state into property_hash for each zone' do
      instances = described_class.instances
      internal = instances.find { |i| i.name == 'internal' }
      expect(internal).not_to be_nil
      expect(internal.get(:target)).to eq('ACCEPT')
      expect(internal.get(:interfaces)).to eq(%w[eth1 eth2])
      expect(internal.get(:sources)).to eq(['192.168.1.0/24'])
      expect(internal.get(:masquerade)).to eq(:true)
      expect(internal.get(:icmp_block_inversion)).to eq(:true)
      expect(internal.get(:icmp_blocks)).to eq(%w[echo-reply echo-request])
      expect(internal.get(:short)).to eq('Internal')
    end

    it 'serves a second prefetched_zones call from the cache' do
      # Only the very first invocation should shell out.
      expect(described_class).to receive(:execute_firewall_cmd).with(['--list-all-zones'], nil).once.and_return(list_all_zones_output)
      described_class.prefetched_zones
      described_class.prefetched_zones
    end

    it 'invalidate_cache! forces a fresh read' do
      expect(described_class).to receive(:execute_firewall_cmd).with(['--list-all-zones'], nil).twice.and_return(list_all_zones_output)
      described_class.prefetched_zones
      Puppet::Provider::Firewalld.invalidate_cache!(:zones)
      described_class.prefetched_zones
    end
  end

  describe '.parse_list_all_output' do
    it 'returns an empty Hash for empty input' do
      expect(Puppet::Provider::Firewalld.parse_list_all_output('')).to eq({})
      expect(Puppet::Provider::Firewalld.parse_list_all_output(nil)).to eq({})
    end

    it 'parses the zone name header with and without the (active) suffix' do
      text = <<~OUTPUT
        trusted
          target: ACCEPT
        public (active)
          target: default
      OUTPUT
      result = Puppet::Provider::Firewalld.parse_list_all_output(text)
      expect(result.keys).to contain_exactly('trusted', 'public')
      expect(result['trusted']['target']).to eq('ACCEPT')
      expect(result['public']['target']).to eq('default')
    end
  end
end
