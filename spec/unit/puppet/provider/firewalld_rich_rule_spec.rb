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
    # rubocop:disable RSpec/AnyInstance
    provider.class.stubs(:execute_firewall_cmd).returns(Object.any_instance.stubs(exitstatus: 0))
    provider.class.stubs(:execute_firewall_cmd).with(['--list-interfaces']).returns(Object.any_instance.stubs(exitstatus: 0, chomp: ''))
    # rubocop:enable RSpec/AnyInstance
  end

  describe 'when creating' do
    context 'with basic parameters' do
      it 'builds the rich rule' do
        resource.expects(:[]).with(:source).returns('192.168.1.2/32').at_least_once
        resource.expects(:[]).with(:service).returns('ssh').at_least_once
        resource.expects(:[]).with('family').returns('ipv4').at_least_once
        resource.expects(:[]).with(:dest).returns(nil)
        resource.expects(:[]).with(:port).returns(nil)
        resource.expects(:[]).with(:protocol).returns(nil)
        resource.expects(:[]).with(:icmp_block).returns(nil)
        resource.expects(:[]).with(:icmp_type).returns(nil)
        resource.expects(:[]).with(:masquerade).returns(nil)
        resource.expects(:[]).with(:forward_port).returns(nil)
        resource.expects(:[]).with(:log).returns(nil)
        resource.expects(:[]).with(:audit).returns(nil)
        resource.expects(:[]).with(:raw_rule).returns(nil)
        resource.expects(:[]).with(:action).returns('accept')
        expect(provider.build_rich_rule).to eq('rule family="ipv4" source service name="ssh" accept')
      end
    end
    context 'with reject type' do
      it 'builds the rich rule' do
        resource.expects(:[]).with(:source).returns(nil).at_least_once
        resource.expects(:[]).with(:service).returns('ssh').at_least_once
        resource.expects(:[]).with('family').returns('ipv4').at_least_once
        resource.expects(:[]).with(:dest).returns('address' => '192.168.0.1/32')
        resource.expects(:[]).with(:port).returns(nil)
        resource.expects(:[]).with(:protocol).returns(nil)
        resource.expects(:[]).with(:icmp_block).returns(nil)
        resource.expects(:[]).with(:icmp_type).returns(nil)
        resource.expects(:[]).with(:masquerade).returns(nil)
        resource.expects(:[]).with(:forward_port).returns(nil)
        resource.expects(:[]).with(:log).returns(nil)
        resource.expects(:[]).with(:audit).returns(nil)
        resource.expects(:[]).with(:raw_rule).returns(nil)
        resource.expects(:[]).with(:action).returns(action: 'reject', type: 'icmp-admin-prohibited')
        expect(provider.build_rich_rule).to eq('rule family="ipv4" destination address="192.168.0.1/32" service name="ssh" reject type="icmp-admin-prohibited"')
      end
    end
  end
end
