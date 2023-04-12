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
    # rubocop:disable RSpec/AnyInstance
    provider.class.stubs(:execute_firewall_cmd_policy).returns(Object.any_instance.stubs(exitstatus: 0))
    provider.class.stubs(:execute_firewall_cmd_policy).with(['--list-ingress-zones']).returns(Object.any_instance.stubs(exitstatus: 0, chomp: ''))
    provider.class.stubs(:execute_firewall_cmd_policy).with(['--list-egress-zones']).returns(Object.any_instance.stubs(exitstatus: 0, chomp: ''))
    # rubocop:enable RSpec/AnyInstance
  end

  describe 'when creating policy' do
    context 'with name public2restricted' do
      it 'should execute firewall_cmd with new-policy' do
        resource.expects(:[]).with(:name).returns('public2restricted').at_least_once
        resource.expects(:[]).with(:target).returns(nil).at_least_once
        resource.expects(:[]).with(:ingress_zones).returns(['public']).at_least_once
        resource.expects(:[]).with(:egress_zones).returns(['restricted']).at_least_once
        resource.expects(:[]).with(:priority).returns(nil).at_least_once
        resource.expects(:[]).with(:icmp_blocks).returns(nil).at_least_once
        resource.expects(:[]).with(:description).returns(nil).at_least_once
        resource.expects(:[]).with(:short).returns('public2restricted').at_least_once
        provider.expects(:execute_firewall_cmd_policy).with(['--list-ingress-zones'])
        provider.expects(:execute_firewall_cmd_policy).with(['--list-egress-zones'])
        provider.expects(:execute_firewall_cmd_policy).with(['--add-ingress-zone', 'public'])
        provider.expects(:execute_firewall_cmd_policy).with(['--add-egress-zone', 'restricted'])
        provider.expects(:execute_firewall_cmd_policy).with(['--new-policy', 'public2restricted'], nil)
        provider.expects(:execute_firewall_cmd_policy).with(['--set-short', 'public2restricted'], 'public2restricted', true, false)

        # Create policy
        provider.create
      end
    end
  end

  describe 'when modifying description' do
    context 'type' do
      it 'should store updated description' do
        resource.expects(:[]).with(:name).returns('public2restricted').at_least_once
        resource.expects(:[]).with(:target).returns(nil).at_least_once
        resource.expects(:[]).with(:ingress_zones).returns(['public']).at_least_once
        resource.expects(:[]).with(:egress_zones).returns(['restricted']).at_least_once
        resource.expects(:[]).with(:priority).returns(nil).at_least_once
        resource.expects(:[]).with(:icmp_blocks).returns(nil).at_least_once
        resource.expects(:[]).with(:description).returns(nil).at_least_once
        resource.expects(:[]).with(:short).returns('public2restricted').at_least_once
        provider.expects(:execute_firewall_cmd_policy).with(['--list-ingress-zones'])
        provider.expects(:execute_firewall_cmd_policy).with(['--list-egress-zones'])
        provider.expects(:execute_firewall_cmd_policy).with(['--add-ingress-zone', 'public'])
        provider.expects(:execute_firewall_cmd_policy).with(['--add-egress-zone', 'restricted'])
        provider.expects(:execute_firewall_cmd_policy).with(['--new-policy', 'public2restricted'], nil)
        provider.expects(:execute_firewall_cmd_policy).with(['--set-short', 'public2restricted'], 'public2restricted', true, false)

        provider.create

        provider.expects(:execute_firewall_cmd_policy).with(['--set-description', :"Modified description"], 'public2restricted', true, false)

        # Modify description
        provider.description = :'Modified description'
      end
    end
  end
end
