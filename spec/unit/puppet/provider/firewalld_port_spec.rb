require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_port).provider(:firewall_cmd)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_port).new(
      ensure: :present,
      name: 'Open port 8080 in the public zone',
      zone: 'public',
      port: '8080',
      protocol: 'tcp'
    )
  end
  let(:provider) { resource.provider }
  let(:fakeclassperm) { Class.new }
  let(:fakeclassrun) { Class.new }
  let(:args) { [['8080/tcp']] }

  describe 'when creating' do
    it 'add port should not execute if rule exists in permanent' do
      provider.in_perm = true
      provider.expects(:execute_firewall_cmd).with(['--add-port', args]).never
      provider.create
    end

    it 'add port should execute if rule does not exist in permanent' do
      provider.in_perm = false
      provider.expects(:execute_firewall_cmd).with(['--add-port', args])
      provider.create
    end
  end

  describe 'when destroying' do
    it 'remove port should execute if rule exists in permanent' do
      provider.in_perm = true
      provider.expects(:execute_firewall_cmd).with(['--remove-port', args])
      provider.destroy
    end

    it 'remove port should not execute if rule does not exist in permanent' do
      provider.in_perm = false
      provider.expects(:execute_firewall_cmd).with(['--remove-port', args]).never
      provider.destroy
    end
  end

  describe 'exists?' do
    let(:resource_absent) do
      @resource_absent = Puppet::Type.type(:firewalld_port).new(
        ensure: :absent,
        name: 'Open port 8080 in the public zone',
        zone: 'public',
        port: '8080',
        protocol: 'tcp'
      )
    end
    let(:provider_absent) { resource_absent.provider }

    it 'port adding should be triggered if rule exists in runtime but not in permanent' do
      fakeclassperm.stubs(:exitstatus).returns(0)
      fakeclassrun.stubs(:exitstatus).returns(1)
      provider.expects(:execute_firewall_cmd).with(['--query-port', args], 'public', false, false).returns(fakeclassperm)
      provider.expects(:execute_firewall_cmd).with(['--query-port', args], 'public', true, false).returns(fakeclassrun)
      expect(provider.exists?).to eq(false)
    end

    it 'port deletion should be triggered if rule exists in runtime but not in permanent' do
      fakeclassperm.stubs(:exitstatus).returns(0)
      fakeclassrun.stubs(:exitstatus).returns(1)
      provider_absent.expects(:execute_firewall_cmd).with(['--query-port', args], 'public', true, false).returns(fakeclassperm)
      provider_absent.expects(:execute_firewall_cmd).with(['--query-port', args], 'public', false, false).returns(fakeclassrun)
      expect(provider_absent.exists?).to eq(true)
    end
  end
end
