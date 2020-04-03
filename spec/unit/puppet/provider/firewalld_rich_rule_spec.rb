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
    scenarios = {
      ## Test source
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        source: { 'address' => '10.0.1.2/24' },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept'
      } => 'rule family="ipv4" source address="10.0.1.2/24" service name="ssh" log level="debug" accept',
      ## Test ipset
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        source: { 'ipset' => 'whitelist' },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept'
      } => 'rule family="ipv4" source ipset="whitelist" service name="ssh" log level="debug" accept',

      ## Test destination
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        dest: '10.0.1.2/24',
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept'
      } => 'rule family="ipv4" destination address="10.0.1.2/24" service name="ssh" log level="debug" accept',

      ## Test address invertion
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        source: { 'address' => '10.0.1.2/24', 'invert' => true },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept'
      } => 'rule family="ipv4" source NOT address="10.0.1.2/24" service name="ssh" log level="debug" accept',
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        dest: { 'address' => '10.0.1.2/24', 'invert' => true },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept'
      } => 'rule family="ipv4" destination NOT address="10.0.1.2/24" service name="ssh" log level="debug" accept',

      ## test port
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        dest: '10.0.1.2/24',
        port: { 'port' => '22', 'protocol' => 'tcp' },
        log: { 'level' => 'debug' },
        action: 'accept'
      } => 'rule family="ipv4" destination address="10.0.1.2/24" port port="22" protocol="tcp" log level="debug" accept',

      ## test forward port
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        forward_port: { 'port' => '8080', 'protocol' => 'tcp', 'to_addr' => '10.72.1.10', 'to_port' => '80' },
        zone: 'restricted',
        log: { 'level' => 'debug' }
      } => 'rule family="ipv4" forward-port port="8080" protocol="tcp" to-port="80" to-addr="10.72.1.10" log level="debug"'

    }

    scenarios.each do |attrs, rawrule|
      context "for rule #{rawrule}" do
        let(:resource) do
          Puppet::Type.type(:firewalld_rich_rule).new(attrs)
        end
        let(:fakeclass) { Class.new }
        let(:provider) { resource.provider }
        let(:rawrule) do
          'rule family="ipv4" source address="10.0.1.2/24" service name="ssh" log level="debug" accept'
        end

        it 'queries the status' do
          fakeclass.stubs(:exitstatus).returns(0)
          provider.expects(:execute_firewall_cmd).with(['--query-rich-rule', rawrule], 'restricted', true, false).returns(fakeclass)
          provider.expects(:execute_firewall_cmd).with(['--query-rich-rule', rawrule], 'restricted', false, false).returns(fakeclass)
          expect(provider).to be_exists
        end

        it 'add rich rule executed when rule does not exist in permanent' do
          provider.in_perm = false
          provider.expects(:execute_firewall_cmd).with(['--add-rich-rule', rawrule])
          provider.create
        end

        it 'remove rich rule executed when rule does exist in permanent' do
          provider.in_perm = true
          provider.expects(:execute_firewall_cmd).with(['--remove-rich-rule', rawrule])
          provider.destroy
        end

        it 'add rich rule does not execute when exist in permanent' do
          provider.in_perm = true
          provider.expects(:execute_firewall_cmd).with(['--add-rich-rule', rawrule]).never
          provider.create
        end

        it 'remove rich rule does not execute when rule does not exist in permanent' do
          provider.in_perm = false
          provider.expects(:execute_firewall_cmd).with(['--remove-rich-rule', rawrule]).never
          provider.destroy
        end
      end
    end

    context 'with basic parameters' do
      it 'builds the rich rule' do
        resource.expects(:[]).with(:source).returns('192.168.1.2/32').at_least_once
        resource.expects(:[]).with(:service).returns('ssh').at_least_once
        resource.expects(:[]).with('family').returns('ipv4').at_least_once
        resource.expects(:[]).with(:dest).returns(nil)
        resource.expects(:[]).with(:port).returns(nil)
        resource.expects(:[]).with(:protocol).returns(nil)
        resource.expects(:[]).with(:icmp_block).returns(nil)
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
