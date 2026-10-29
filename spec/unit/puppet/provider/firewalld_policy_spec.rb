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

  describe 'self.instances' do
    it 'reflects every existing policy' do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--get-policies'], nil).and_return('anytorestricted allow-host-ipv6')
      expect(provider_class.instances.map(&:name)).to contain_exactly('anytorestricted', 'allow-host-ipv6')
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by name, since the policy namevar is the policy name itself' do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--get-policies'], nil).and_return('anytorestricted allow-host-ipv6')
      policy = Puppet::Type.type(:firewalld_policy).new(name: 'anytorestricted', ingress_zones: ['public'], egress_zones: ['restricted'])

      provider_class.prefetch('anytorestricted' => policy)

      expect(policy.provider.exists?).to be true
    end

    it 'does not falsely report present for an unconfigured policy' do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--get-policies'], nil).and_return('anytorestricted')
      policy = Puppet::Type.type(:firewalld_policy).new(name: 'other-policy', ingress_zones: ['public'], egress_zones: ['restricted'])

      provider_class.prefetch('other-policy' => policy)

      expect(policy.provider.exists?).to be false
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      policy = Puppet::Type.type(:firewalld_policy).new(name: 'anytorestricted', ingress_zones: ['public'], egress_zones: ['restricted'])
      policy.provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(policy.provider).not_to receive(:execute_firewall_cmd_policy)
      expect(policy.provider.exists?).to be true
    end

    it 'falls back to a live query when the resource was never prefetched' do
      policy = Puppet::Type.type(:firewalld_policy).new(name: 'anytorestricted', ingress_zones: ['public'], egress_zones: ['restricted'], ensure: :absent)

      expect(policy.provider).to receive(:execute_firewall_cmd_policy).with(['--get-policies'], nil).and_return('anytorestricted')
      expect(policy.provider.exists?).to be true
    end
  end
end
