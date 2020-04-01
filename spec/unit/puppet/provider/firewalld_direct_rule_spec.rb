require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_direct_rule).provider(:firewall_cmd)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_direct_rule).new(
      ensure: :present,
      name: 'Allow outgoing SSH connection',
      inet_protocol: 'ipv4',
      table: 'filter',
      chain: 'OUTPUT',
      priority: 1,
      args: '-p tcp --dport=22 -j ACCEPT'
    )
  end
  let(:provider) { resource.provider }
  let(:rule_args) { %w[ipv4 filter OUTPUT 1 -p tcp --dport=22 -j ACCEPT] }

  describe 'when creating' do
    it 'direct rule should not be created if rule exists in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, true, false).returns('yes')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, false, false).returns('no')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--add-rule', rule_args]).never
      provider.exists?
      provider.create
    end

    it 'creates' do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, true, false).returns('no')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, false, false).returns('no')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--add-rule', rule_args], nil)
      provider.exists?
      provider.create
    end
  end

  describe 'when destroying' do
    it 'destroys' do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, true, false).returns('yes')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, false, false).returns('yes')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--remove-rule', rule_args], nil)
      provider.exists?
      provider.destroy
    end

    it 'direct rule should not be destroyed if it doesnt exist in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, true, false).returns('no')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, false, false).returns('yes')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--remove-rule', rule_args]).never
      provider.exists?
      provider.destroy
    end
  end

  describe 'exists?' do
    let(:resource_absent) do
      @resource_absent = Puppet::Type.type(:firewalld_direct_rule).new(
        ensure: :absent,
        name: 'Allow outgoing SSH connection',
        inet_protocol: 'ipv4',
        table: 'filter',
        chain: 'OUTPUT',
        priority: 1,
        args: '-p tcp --dport=22 -j ACCEPT'
      )
    end
    let(:provider_absent) { resource_absent.provider }

    it 'direct rule creation should be triggered if rule exists in runtime but not in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, true, false).returns('no')
      provider.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, false, false).returns('yes')
      expect(provider.exists?).to eq(false)
    end

    it 'direct rule deletion should be triggered if rule exists in runtime but not in permanent' do
      provider_absent.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, true, false).returns('no')
      provider_absent.expects(:execute_firewall_cmd).with(['--direct', '--query-rule', rule_args], nil, false, false).returns('yes')
      expect(provider_absent.exists?).to eq(true)
    end
  end

  context 'parsing arguments' do
    it 'correctlies parse arguments into an array' do
      args = '-p tcp --dport=22 -j ACCEPT'
      expect(provider.parse_args(args)).to eq(['-p', 'tcp', '--dport=22', '-j', 'ACCEPT'])
    end

    it 'correctlies parse arguments in quotes' do
      args = "-j LOG --log-prefix '# IPTABLES DROPPED:'"
      expect(provider.parse_args(args)).to eq(['-j', 'LOG', '--log-prefix', '\'# IPTABLES DROPPED:\''])
    end
  end
end
