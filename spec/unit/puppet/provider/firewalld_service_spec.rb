require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_service).provider(:firewall_cmd)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_service).new(
      ensure: :present,
      name: 'Allow SSH from the external zone',
      service: 'ssh',
      zone: 'external'
    )
  end
  let(:provider) { resource.provider }

  describe 'when creating' do
    it 'service should not be added if rule exists in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--list-services']).returns('ssh http')
      provider.expects(:execute_firewall_cmd).with(['--list-services'], nil, false).returns('ssh http')
      provider.expects(:execute_firewall_cmd).with(%w[--add-service ssh]).never
      provider.exists?
      provider.create
    end

    it 'service should be added if rule does not exist in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--list-services']).returns('')
      provider.expects(:execute_firewall_cmd).with(['--list-services'], nil, false).returns('')
      provider.expects(:execute_firewall_cmd).with(%w[--add-service ssh]).once
      provider.exists?
      provider.create
    end
  end

  describe 'when destroying' do
    it 'service should not be deleted if rule does not exist in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--list-services']).returns('')
      provider.expects(:execute_firewall_cmd).with(['--list-services'], nil, false).returns('')
      provider.expects(:execute_firewall_cmd).with(%w[--remove-service-from-zone ssh]).never
      provider.exists?
      provider.destroy
    end

    it 'service should be deleted if rule exists in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--list-services']).returns('ssh http')
      provider.expects(:execute_firewall_cmd).with(['--list-services'], nil, false).returns('ssh http')
      provider.expects(:execute_firewall_cmd).with(%w[--remove-service-from-zone ssh]).once
      provider.exists?
      provider.destroy
    end
  end

  describe 'exists?' do
    let(:resource_absent) do
      @resource_absent = Puppet::Type.type(:firewalld_service).new(
        ensure: :absent,
        name: 'Allow SSH from the external zone',
        service: 'ssh',
        zone: 'external'
      )
    end
    let(:provider_absent) { resource_absent.provider }

    it 'service creation should be triggered if rule exists in runtime but not in permanent' do
      provider.expects(:execute_firewall_cmd).with(['--list-services']).returns('')
      provider.expects(:execute_firewall_cmd).with(['--list-services'], nil, false).returns('ssh http')
      expect(provider.exists?).to eq(false)
    end

    it 'service deletion should be triggered if rule exists in runtime but not in permanent' do
      provider_absent.expects(:execute_firewall_cmd).with(['--list-services']).returns('')
      provider_absent.expects(:execute_firewall_cmd).with(['--list-services'], nil, false).returns('ssh http')
      expect(provider_absent.exists?).to eq(true)
    end
  end
end
