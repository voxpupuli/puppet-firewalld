# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_policy).provider(:firewall_cmd)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_policy).new(
      ensure: :present,
      name: 'public2restricted',
      description: 'Public to restricted',
      ingress_zones: ['public'],
      egress_zones: ['restricted'],
      provider: described_class.name,
    )
  end
  let(:provider) { resource.provider }

  before do
    # Every test starts with a clean transaction cache so that prefetched
    # state from one example does not leak into another.
    Puppet::Provider::Firewalld.invalidate_cache!
    allow(provider).to receive(:execute_firewall_cmd_policy).and_return(double(exitstatus: 0))
    allow(provider).to receive(:execute_firewall_cmd_policy).with(['--list-ingress-zones']).and_return(double(exitstatus: 0, chomp: ''))
    allow(provider).to receive(:execute_firewall_cmd_policy).with(['--list-egress-zones']).and_return(double(exitstatus: 0, chomp: ''))
  end

  describe 'when creating policy' do
    context 'with name public2restricted' do
      it 'executes firewall_cmd with new-policy' do
        expect(resource).to receive(:[]).with(:name).and_return('public2restricted').at_least(:once)
        expect(resource).to receive(:[]).with(:target).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:ingress_zones).and_return(['public']).at_least(:once)
        expect(resource).to receive(:[]).with(:egress_zones).and_return(['restricted']).at_least(:once)
        expect(resource).to receive(:[]).with(:priority).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_blocks).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:description).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:short).and_return('public2restricted').at_least(:once)
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--list-ingress-zones'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--list-egress-zones'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--add-ingress-zone', 'public'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--add-egress-zone', 'restricted'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--new-policy', 'public2restricted'], nil)
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--set-short', 'public2restricted'], 'public2restricted', true, false)

        provider.create
      end
    end
  end

  describe 'when modifying description' do
    context 'type' do
      it 'stores updated description' do
        expect(resource).to receive(:[]).with(:name).and_return('public2restricted').at_least(:once)
        expect(resource).to receive(:[]).with(:target).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:ingress_zones).and_return(['public']).at_least(:once)
        expect(resource).to receive(:[]).with(:egress_zones).and_return(['restricted']).at_least(:once)
        expect(resource).to receive(:[]).with(:priority).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_blocks).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:description).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:short).and_return('public2restricted').at_least(:once)
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--list-ingress-zones'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--list-egress-zones'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--add-ingress-zone', 'public'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--add-egress-zone', 'restricted'])
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--new-policy', 'public2restricted'], nil)
        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--set-short', 'public2restricted'], 'public2restricted', true, false)

        provider.create

        expect(provider).to receive(:execute_firewall_cmd_policy).with(['--set-description', :'Modified description'], 'public2restricted', true, false)

        provider.description = :'Modified description'
      end
    end
  end

  describe 'bulk prefetch' do
    let(:list_all_policies_output) do
      <<~OUTPUT
        anytorestricted (active)
          priority: -1
          target: REJECT
          ingress-zones: ANY
          egress-zones: restricted
          services:
          ports:
          protocols:
          masquerade: no
          forward-ports:
          source-ports:
          icmp-blocks: router-advertisement
          rich rules:
          description: Any to restricted
          short: a2r

        public2restricted (active)
          priority: 100
          target: default
          ingress-zones: public
          egress-zones: restricted
          masquerade: yes
          description: Public to restricted
          short: p2r
      OUTPUT
    end

    before do
      allow(described_class).to receive(:execute_firewall_cmd).with(['--list-all-policies'], nil, nil).and_return(list_all_policies_output)
    end

    after do
      Puppet::Provider::Firewalld.invalidate_cache!
    end

    it 'parses policy state into property_hash for each policy' do
      instances = described_class.instances
      p2r = instances.find { |i| i.name == 'public2restricted' }
      expect(p2r).not_to be_nil
      expect(p2r.get(:target)).to eq('default')
      expect(p2r.get(:ingress_zones)).to eq(['public'])
      expect(p2r.get(:egress_zones)).to eq(['restricted'])
      expect(p2r.get(:priority)).to eq('100')
      expect(p2r.get(:masquerade)).to eq(:true)
      expect(p2r.get(:short)).to eq('p2r')
    end

    it 'serves a second prefetched_policies call from the cache' do
      described_class.prefetched_policies
      described_class.prefetched_policies
      expect(described_class).to have_received(:execute_firewall_cmd).with(['--list-all-policies'], nil, nil).once
    end

    it 'invalidate_cache! forces a fresh read' do
      described_class.prefetched_policies
      Puppet::Provider::Firewalld.invalidate_cache!(:policies)
      described_class.prefetched_policies
      expect(described_class).to have_received(:execute_firewall_cmd).with(['--list-all-policies'], nil, nil).twice
    end
  end
end
