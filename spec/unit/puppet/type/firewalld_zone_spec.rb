# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'
RSpec.configure { |c| c.mock_with :rspec }

describe Puppet::Type.type(:firewalld_zone) do
  before do
    allow_any_instance_of(Puppet::Provider::Firewalld).to receive(:state).and_return(true)
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-zones'], nil).and_return('public restricted')
        expect(provider).to be_exists
      end

      it 'evalulates target' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-target']).and_return('%%REJECT%%')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'gets forwarding state as false when not set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-forward'], 'restricted', true, false).and_return("no\n")
        expect(provider.forward).to eq(:false)
      end

      it 'gets masquerading state as false when not set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-masquerade'], 'restricted', true, false).and_return("no\n")
        expect(provider.masquerade).to eq(:false)
      end

      it 'sets target' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])
        provider.target = '%%REJECT%%'
      end

      it 'gets interfaces' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-interfaces']).and_return('')
        provider.interfaces
      end

      it 'sets interfaces' do
        expect(provider).to receive(:interfaces).and_return(['eth1'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-interface', 'eth1'])
        provider.interfaces = ['eth0']
      end

      it 'creates' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-zone', 'restricted'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-icmp-block-inversion'], 'restricted')

        expect(provider).to receive(:interfaces).and_return([])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-zones'], nil).and_return('public restricted')
        expect(provider).to be_exists
      end

      it 'checks if it doesnt exist' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-zones'], nil).and_return('public private')
        expect(provider).not_to be_exists
      end

      it 'evalulates target' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-target']).and_return('%%REJECT%%')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'evalulates target correctly when not surrounded with %%' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-target']).and_return('REJECT')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'gets forwarding state as false when not set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-forward'], 'restricted', true, false).and_return("no\n")
        expect(provider.forward).to eq(:false)
      end

      it 'gets masquerading state as false when not set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-masquerade'], 'restricted', true, false).and_return("no\n")
        expect(provider.masquerade).to eq(:false)
      end

      it 'creates' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-zone', 'restricted'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])

        expect(provider).to receive(:icmp_blocks=).with(%w[redirect router-advertisment])
        expect(provider).to receive(:icmp_block_inversion=).with(:true)

        expect(provider).to receive(:sources).and_return([])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-source', '192.168.2.2'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-source', '10.72.1.100'])

        expect(provider).to receive(:protocols).and_return([])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-protocol', 'icmp'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-protocol', 'igmp'])

        expect(provider).to receive(:interfaces).and_return([])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        provider.create
      end

      it 'removes' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--delete-zone', 'restricted'], nil)
        provider.destroy
      end

      it 'sets target' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--set-target', '%%REJECT%%'])
        provider.target = '%%REJECT%%'
      end

      it 'gets interfaces' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-interfaces']).and_return('')
        provider.interfaces
      end

      it 'sets interfaces' do
        expect(provider).to receive(:interfaces).and_return(['eth1'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-interface', 'eth0'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-interface', 'eth1'])
        provider.interfaces = ['eth0']
      end

      it 'gets sources' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-sources']).and_return('val val')
        expect(provider.sources).to eq(%w[val val])
      end

      it 'sources should always return in alphanumerical order' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-sources']).and_return('4.4.4.4/32 2.2.2.2/32 3.3.3.3/32')
        expect(provider.sources).to eq(['2.2.2.2/32', '3.3.3.3/32', '4.4.4.4/32'])
      end

      it 'sets sources' do
        expect(provider).to receive(:sources).and_return(['valx'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-source', 'valy'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-source', 'valx'])
        provider.sources = ['valy']
      end

      it 'gets icmp_block_inversion' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-icmp-block-inversion'], 'restricted', true, false).and_return("no\n")
        expect(provider.icmp_block_inversion).to eq(:false)
      end

      it 'lists icmp types' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-icmptypes'], nil).and_return('echo-reply echo-request')
        expect(provider.get_icmp_types).to eq(%w[echo-reply echo-request])
      end

      it 'gets protocols' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-protocols']).and_return('val val')
        expect(provider.protocols).to eq(%w[val val])
      end

      it 'sets protocols' do
        expect(provider).to receive(:protocols).and_return(['valx'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-protocol', 'valy'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-protocol', 'valx'])
        provider.protocols = ['valy']
      end

      it 'gets icmp_blocks' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-icmp-blocks'], 'restricted').and_return('redirect router-advertisement')
        expect(provider.icmp_blocks).to eq(%w[redirect router-advertisement])
      end

      it 'sets icmp_blocks' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-icmp-blocks'], 'restricted').and_return('redirect router-advertisement')
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-icmptypes'], nil).and_return(icmptypes.join(' '))
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-icmp-block', 'bad-header'], 'restricted')
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-icmp-block', 'router-advertisement'], 'restricted')
        provider.icmp_blocks = %w[redirect bad-header]
      end
    end

    context 'when specifiying forward' do
      let(:resource) do
        described_class.new(
          name: 'public',
          ensure: :present,
          forward: true
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'sets forwarding' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-forward'], 'public')
        provider.forward = :true
      end

      it 'disables forwarding' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-forward'], 'public')
        provider.forward = :false
      end

      it 'gets forwarding state as false when not set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-forward'], 'public', true, false).and_return("no\n")
        expect(provider.forward).to eq(:false)
      end

      it 'gets forwarding state as true when set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-forward'], 'public', true, false).and_return("yes\n")
        expect(provider.forward).to eq(:true)
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-masquerade'], 'public')
        provider.masquerade = :true
      end

      it 'disables masquerading' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-masquerade'], 'public')
        provider.masquerade = :false
      end

      it 'gets masquerading state as false when not set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-masquerade'], 'public', true, false).and_return("no\n")
        expect(provider.masquerade).to eq(:false)
      end

      it 'gets masquerading state as true when set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-masquerade'], 'public', true, false).and_return("yes\n")
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-icmp-block-inversion'], 'public')
        provider.icmp_block_inversion = :true
      end

      it 'disables icmp_block_inversion' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--remove-icmp-block-inversion'], 'public')
        provider.icmp_block_inversion = :false
      end

      it 'gets icmp_block_inversion state as false when not set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-icmp-block-inversion'], 'public', true, false).and_return("no\n")
        expect(provider.icmp_block_inversion).to eq(:false)
      end

      it 'gets icmp_block_inversion state as true when set' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--query-icmp-block-inversion'], 'public', true, false).and_return("yes\n")
        expect(provider.icmp_block_inversion).to eq(:true)
      end

      it 'sets icmp_blocks' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--list-icmp-blocks'], 'public').and_return('')
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-icmptypes'], nil).and_return(icmptypes.join(' '))
        expect(provider).to receive(:execute_firewall_cmd).with(['--add-icmp-block', 'echo-request'], 'public')
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--get-icmptypes'], nil).and_return(icmptypes.join(' '))
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
