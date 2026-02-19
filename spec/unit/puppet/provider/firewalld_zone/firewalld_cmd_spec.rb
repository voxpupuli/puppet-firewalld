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
      provider: described_class.name
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
end
