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
      provider: described_class.name
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
end
