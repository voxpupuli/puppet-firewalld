require 'spec_helper'

describe Puppet::Type.type(:firewalld_zone) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true) # rubocop:disable RSpec/AnyInstance
  end

  describe 'type' do
    context 'with no params' do
      describe 'when validating attributes' do
        [
          :name
        ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end

        [:target, :icmp_blocks, :sources, :purge_rich_rules, :purge_services, :purge_ports].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:property)
          end
        end
      end
    end
  end

  ## Provider tests for the firewalld_zone type
  #
  describe 'provider' do
    context 'with standard parameters' do
      let(:resource) do
        described_class.new(
          name: 'restricted',
          target: '%%REJECT%%',
          interfaces: ['eth0'],
          icmp_blocks: ['redirect', 'router-advertisment'],
          sources: ['192.168.2.2', '10.72.1.100']
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'checks if it exists' do
        provider.expects(:execute_firewall_cmd).with(['--get-zones'], nil).returns('public restricted')
        expect(provider).to be_exists
      end

      it 'checks if it doesnt exist' do
        provider.expects(:execute_firewall_cmd).with(['--get-zones'], nil).returns('public private')
        expect(provider).not_to be_exists
      end

      it 'evalulates target' do
        provider.expects(:execute_firewall_cmd).with(['--get-target']).returns('%%REJECT%%')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'evalulates target correctly when not surrounded with %%' do
        provider.expects(:execute_firewall_cmd).with(['--get-target']).returns('REJECT')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'creates' do
        provider.expects(:execute_firewall_cmd).with(['--new-zone', 'restricted'], nil)
        provider.expects(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])

        provider.expects(:icmp_blocks=).with(['redirect', 'router-advertisment'])

        provider.expects(:sources).returns([])
        provider.expects(:execute_firewall_cmd).with(['--add-source', '192.168.2.2'])
        provider.expects(:execute_firewall_cmd).with(['--add-source', '10.72.1.100'])

        provider.expects(:interfaces).returns([])
        provider.expects(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        provider.create
      end

      it 'removes' do
        provider.expects(:execute_firewall_cmd).with(['--delete-zone', 'restricted'], nil)
        provider.destroy
      end

      it 'sets target' do
        provider.expects(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])
        provider.target = '%%REJECT%%'
      end

      it 'gets interfaces' do
        provider.expects(:execute_firewall_cmd).with(['--list-interfaces']).returns('')
        provider.interfaces
      end

      it 'sets interfaces' do
        provider.expects(:interfaces).returns(['eth1'])
        provider.expects(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        provider.expects(:execute_firewall_cmd).with(['--remove-interface', 'eth1'])
        provider.interfaces = ['eth0']
      end

      it 'gets sources' do
        provider.expects(:execute_firewall_cmd).with(['--list-sources']).returns('val val')
        expect(provider.sources).to eq(%w[val val])
      end

      it 'sources should always return in alphanumerical order' do
        provider.expects(:execute_firewall_cmd).with(['--list-sources']).returns('4.4.4.4/32 2.2.2.2/32 3.3.3.3/32')
        expect(provider.sources).to eq(['2.2.2.2/32', '3.3.3.3/32', '4.4.4.4/32'])
      end

      it 'sets sources' do
        provider.expects(:sources).returns(['valx'])
        provider.expects(:execute_firewall_cmd).with(['--add-source', 'valy'])
        provider.expects(:execute_firewall_cmd).with(['--remove-source', 'valx'])
        provider.sources = ['valy']
      end

      it 'gets icmp_blocks' do
        provider.expects(:execute_firewall_cmd).with(['--list-icmp-blocks']).returns('val')
        expect(provider.icmp_blocks).to eq(['val'])
      end

      it 'lists icmp types' do
        provider.expects(:execute_firewall_cmd).with(['--get-icmptypes'], nil).returns('echo-reply echo-request')
        expect(provider.get_icmp_types).to eq(['echo-reply', 'echo-request'])
      end
    end

    context 'when specifiying masquerade' do
      let(:resource) do
        described_class.new(
          name: 'public',
          ensure: :present,
          masquerade: true
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'sets masquerading' do
        provider.expects(:execute_firewall_cmd).with(['--add-masquerade'])
        provider.masquerade = :true
      end

      it 'disables masquerading' do
        provider.expects(:execute_firewall_cmd).with(['--remove-masquerade'])
        provider.masquerade = :false
      end

      it 'gets masquerading state as false when not set' do
        provider.expects(:execute_firewall_cmd).with(['--query-masquerade'], 'public', true, false).returns("no\n")
        expect(provider.masquerade).to eq(:false)
      end
      it 'gets masquerading state as true when set' do
        provider.expects(:execute_firewall_cmd).with(['--query-masquerade'], 'public', true, false).returns("yes\n")
        expect(provider.masquerade).to eq(:true)
      end
    end
  end

  context 'autorequires' do
    # rubocop:disable RSpec/InstanceVariable
    before do
      firewalld_service = Puppet::Type.type(:service).new(name: 'firewalld')
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(firewalld_service)
    end

    it 'autorequires the firewalld service' do
      resource = described_class.new(name: 'test')
      @catalog.add_resource(resource)

      expect(resource.autorequire.map { |rp| rp.source.to_s }).to include('Service[firewalld]')
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
