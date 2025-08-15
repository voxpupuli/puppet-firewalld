# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_rich_rule).provider(:firewall_cmd)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_rich_rule).new(
      ensure: :present,
      name: 'Accept ssh from barny',
      zone: 'restricted',
      service: 'ssh',
      source: '192.168.1.2/32',
      action: 'accept',
      provider: described_class.name
    )
  end
  let(:provider) { resource.provider }

  before do
    allow(provider).to receive(:execute_firewall_cmd).and_return(double(exitstatus: 0))
    allow(provider).to receive(:execute_firewall_cmd).with(['--list-interfaces']).and_return(double(exitstatus: 0, chomp: ''))
  end

  describe 'when creating' do
    context 'with basic parameters' do
      it 'builds the rich rule' do
        expect(resource).to receive(:[]).with(:priority).and_return(nil)
        expect(resource).to receive(:[]).with(:source).and_return('192.168.1.2/32').at_least(:once)
        expect(resource).to receive(:[]).with(:service).and_return('ssh').at_least(:once)
        expect(resource).to receive(:[]).with('family').and_return('ipv4').at_least(:once)
        expect(resource).to receive(:[]).with(:dest).and_return(nil)
        expect(resource).to receive(:[]).with(:port).and_return(nil)
        expect(resource).to receive(:[]).with(:protocol).and_return(nil)
        expect(resource).to receive(:[]).with(:icmp_block).and_return(nil)
        expect(resource).to receive(:[]).with(:icmp_type).and_return(nil)
        expect(resource).to receive(:[]).with(:masquerade).and_return(nil)
        expect(resource).to receive(:[]).with(:forward_port).and_return(nil)
        expect(resource).to receive(:[]).with(:log).and_return(nil)
        expect(resource).to receive(:[]).with(:audit).and_return(nil)
        expect(resource).to receive(:[]).with(:raw_rule).and_return(nil)
        expect(resource).to receive(:[]).with(:action).and_return('accept')
        expect(provider.build_rich_rule).to eq('rule family="ipv4" source service name="ssh" accept')
      end
    end

    context 'with reject type' do
      it 'builds the rich rule' do
        expect(resource).to receive(:[]).with(:priority).and_return(nil)
        expect(resource).to receive(:[]).with(:source).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:service).and_return('ssh').at_least(:once)
        expect(resource).to receive(:[]).with('family').and_return('ipv4').at_least(:once)
        expect(resource).to receive(:[]).with(:dest).and_return('address' => '192.168.0.1/32')
        expect(resource).to receive(:[]).with(:port).and_return(nil)
        expect(resource).to receive(:[]).with(:protocol).and_return(nil)
        expect(resource).to receive(:[]).with(:icmp_block).and_return(nil)
        expect(resource).to receive(:[]).with(:icmp_type).and_return(nil)
        expect(resource).to receive(:[]).with(:masquerade).and_return(nil)
        expect(resource).to receive(:[]).with(:forward_port).and_return(nil)
        expect(resource).to receive(:[]).with(:log).and_return(nil)
        expect(resource).to receive(:[]).with(:audit).and_return(nil)
        expect(resource).to receive(:[]).with(:raw_rule).and_return(nil)
        expect(resource).to receive(:[]).with(:action).and_return('action' => 'reject', 'type' => 'icmp-admin-prohibited')
        expect(provider.build_rich_rule).to eq('rule family="ipv4" destination address="192.168.0.1/32" service name="ssh" reject type="icmp-admin-prohibited"')
      end
    end

    context 'with priority' do
      it 'builds the rich rule' do
        expect(resource).to receive(:[]).with(:priority).and_return(1200)
        expect(resource).to receive(:[]).with(:source).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:service).and_return('ssh').at_least(:once)
        expect(resource).to receive(:[]).with('family').and_return('ipv4').at_least(:once)
        expect(resource).to receive(:[]).with(:dest).and_return('address' => '192.168.0.1/32')
        expect(resource).to receive(:[]).with(:port).and_return(nil)
        expect(resource).to receive(:[]).with(:protocol).and_return(nil)
        expect(resource).to receive(:[]).with(:icmp_block).and_return(nil)
        expect(resource).to receive(:[]).with(:icmp_type).and_return(nil)
        expect(resource).to receive(:[]).with(:masquerade).and_return(nil)
        expect(resource).to receive(:[]).with(:forward_port).and_return(nil)
        expect(resource).to receive(:[]).with(:log).and_return(nil)
        expect(resource).to receive(:[]).with(:audit).and_return(nil)
        expect(resource).to receive(:[]).with(:raw_rule).and_return(nil)
        expect(resource).to receive(:[]).with(:action).and_return('action' => 'reject', 'type' => 'icmp-admin-prohibited')
        expect(provider.build_rich_rule).to eq('rule family="ipv4" priority="1200" destination address="192.168.0.1/32" service name="ssh" reject type="icmp-admin-prohibited"')
      end
    end
  end
end
