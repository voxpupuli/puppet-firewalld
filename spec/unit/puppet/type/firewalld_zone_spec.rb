# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:firewalld_zone) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true) # rubocop:disable RSpec/AnyInstance
  end

  let(:icmptypes) do
    %w[
      address-unreachable
      bad-header
      beyond-scope
      communication-prohibited
      destination-unreachable
      echo-reply
      echo-request
      failed-policy
      fragmentation-needed
      host-precedence-violation
      host-prohibited
      host-redirect
      host-unknown
      host-unreachable
      ip-header-bad
      neighbour-advertisement
      neighbour-solicitation
      network-prohibited
      network-redirect
      network-unknown
      network-unreachable
      no-route
      packet-too-big
      parameter-problem
      port-unreachable
      precedence-cutoff
      protocol-unreachable
      redirect
      reject-route
      required-option-missing
      router-advertisement
      router-solicitation
      source-quench
      source-route-failed
      time-exceeded
      timestamp-reply
      timestamp-request
      tos-host-redirect
      tos-host-unreachable
      tos-network-redirect
      tos-network-unreachable
      ttl-zero-during-reassembly
      ttl-zero-during-transit
      unknown-header-type
      unknown-option
    ]
  end

  describe 'type' do
    context 'with no params' do
      describe 'when validating attributes' do
        [
          :name
        ].each do |param|
          it "has a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end

        %i[target icmp_blocks icmp_block_inversion sources protocols purge_rich_rules purge_services purge_ports].each do |param|
          it "has a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:property)
          end
        end
      end
    end
  end

  ## Provider tests for the firewalld_zone type
  #
  describe 'provider' do
    context 'with minimal parameters' do
      let(:resource) do
        described_class.new(
          name: 'restricted',
          target: '%%REJECT%%',
          interfaces: ['eth0']
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'checks if it exists' do
        provider.expects(:execute_firewall_cmd).with(['--get-zones'], nil).returns('public restricted')
        expect(provider).to be_exists
      end

      it 'evalulates target' do
        provider.expects(:execute_firewall_cmd).with(['--get-target']).returns('%%REJECT%%')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'gets masquerading state as false when not set' do
        provider.expects(:execute_firewall_cmd).with(['--query-masquerade'], 'restricted', true, false).returns("no\n")
        expect(provider.masquerade).to eq(:false)
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

      it 'creates' do
        provider.expects(:execute_firewall_cmd).with(['--new-zone', 'restricted'], nil)
        provider.expects(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])
        provider.expects(:execute_firewall_cmd).with(['--remove-icmp-block-inversion'], 'restricted')

        provider.expects(:interfaces).returns([])
        provider.expects(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        provider.create
      end
    end

    context 'with standard parameters' do
      let(:resource) do
        described_class.new(
          name: 'restricted',
          target: '%%REJECT%%',
          interfaces: ['eth0'],
          icmp_blocks: %w[redirect router-advertisment],
          icmp_block_inversion: true,
          protocols: %w[icmp igmp],
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

      it 'gets masquerading state as false when not set' do
        provider.expects(:execute_firewall_cmd).with(['--query-masquerade'], 'restricted', true, false).returns("no\n")
        expect(provider.masquerade).to eq(:false)
      end

      it 'creates' do
        provider.expects(:execute_firewall_cmd).with(['--new-zone', 'restricted'], nil)
        provider.expects(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])

        provider.expects(:icmp_blocks=).with(%w[redirect router-advertisment])
        provider.expects(:icmp_block_inversion=).with(:true)

        provider.expects(:sources).returns([])
        provider.expects(:execute_firewall_cmd).with(['--add-source', '192.168.2.2'])
        provider.expects(:execute_firewall_cmd).with(['--add-source', '10.72.1.100'])

        provider.expects(:protocols).returns([])
        provider.expects(:execute_firewall_cmd).with(['--add-protocol', 'icmp'])
        provider.expects(:execute_firewall_cmd).with(['--add-protocol', 'igmp'])

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

      it 'gets icmp_block_inversion' do
        provider.expects(:execute_firewall_cmd).with(['--query-icmp-block-inversion'], 'restricted', true, false).returns("no\n")
        expect(provider.icmp_block_inversion).to eq(:false)
      end

      it 'lists icmp types' do
        provider.expects(:execute_firewall_cmd).with(['--get-icmptypes'], nil).returns('echo-reply echo-request')
        expect(provider.get_icmp_types).to eq(%w[echo-reply echo-request])
      end

      it 'gets protocols' do
        provider.expects(:execute_firewall_cmd).with(['--list-protocols']).returns('val val')
        expect(provider.protocols).to eq(%w[val val])
      end

      it 'sets protocols' do
        provider.expects(:protocols).returns(['valx'])
        provider.expects(:execute_firewall_cmd).with(['--add-protocol', 'valy'])
        provider.expects(:execute_firewall_cmd).with(['--remove-protocol', 'valx'])
        provider.protocols = ['valy']
      end

      it 'gets icmp_blocks' do
        provider.expects(:execute_firewall_cmd).with(['--list-icmp-blocks'], 'restricted').returns('redirect router-advertisement')
        expect(provider.icmp_blocks).to eq(%w[redirect router-advertisement])
      end

      it 'sets icmp_blocks' do
        provider.expects(:execute_firewall_cmd).with(['--list-icmp-blocks'], 'restricted').returns('redirect router-advertisement')
        provider.expects(:execute_firewall_cmd).with(['--get-icmptypes'], nil).returns(icmptypes.join(' '))
        provider.expects(:execute_firewall_cmd).with(['--add-icmp-block', 'bad-header'], 'restricted')
        provider.expects(:execute_firewall_cmd).with(['--remove-icmp-block', 'router-advertisement'], 'restricted')
        provider.icmp_blocks = %w[redirect bad-header]
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
        provider.expects(:execute_firewall_cmd).with(['--add-masquerade'], 'public')
        provider.masquerade = :true
      end

      it 'disables masquerading' do
        provider.expects(:execute_firewall_cmd).with(['--remove-masquerade'], 'public')
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

    context 'when specifiying a single icmp block' do
      let(:resource) do
        described_class.new(
          name: 'public',
          ensure: :present,
          sources: '192.168.2.2',
          icmp_blocks: 'echo-request'
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'sets icmp_block_inversion' do
        provider.expects(:execute_firewall_cmd).with(['--add-icmp-block-inversion'], 'public')
        provider.icmp_block_inversion = :true
      end

      it 'disables icmp_block_inversion' do
        provider.expects(:execute_firewall_cmd).with(['--remove-icmp-block-inversion'], 'public')
        provider.icmp_block_inversion = :false
      end

      it 'gets icmp_block_inversion state as false when not set' do
        provider.expects(:execute_firewall_cmd).with(['--query-icmp-block-inversion'], 'public', true, false).returns("no\n")
        expect(provider.icmp_block_inversion).to eq(:false)
      end

      it 'gets icmp_block_inversion state as true when set' do
        provider.expects(:execute_firewall_cmd).with(['--query-icmp-block-inversion'], 'public', true, false).returns("yes\n")
        expect(provider.icmp_block_inversion).to eq(:true)
      end

      it 'sets icmp_blocks' do
        provider.expects(:execute_firewall_cmd).with(['--list-icmp-blocks'], 'public').returns('')
        provider.expects(:execute_firewall_cmd).with(['--get-icmptypes'], nil).returns(icmptypes.join(' '))
        provider.expects(:execute_firewall_cmd).with(['--add-icmp-block', 'echo-request'], 'public')
        provider.icmp_blocks = %w[echo-request]
      end
    end

    context 'when specifiying a bad icmp block' do
      let(:resource) do
        described_class.new(
          name: 'public',
          ensure: :present,
          sources: '192.168.2.2',
          icmp_blocks: 'invalid-request'
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'errors out' do
        provider.expects(:execute_firewall_cmd).with(['--get-icmptypes'], nil).returns(icmptypes.join(' '))
        expect { provider.icmp_blocks = 'banana' }.to raise_error(Puppet::Error, %r{Invalid ICMP types})
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
