require 'spec_helper'

describe Puppet::Type.type(:firewalld_direct_rule) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true) # rubocop:disable RSpec/AnyInstance
  end

  context 'with no params' do
    describe 'when validating attributes' do
      [:inet_protocol, :args, :table, :chain, :priority].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      let(:attrs) do
        {
          title: 'Allow SSH',
          ensure: 'present',
          table: 'filter',
          chain: 'OUTPUT',
          priority: 1,
          args: '-p tcp ---dport=22 -j ACCEPT'
        }
      end

      it 'has :name as its namevar' do
        expect(described_class.key_attributes).to eq([:name])
      end

      it 'defaults inet_protocol to ipv4' do
        resource = described_class.new(attrs)
        expect(resource[:inet_protocol]).to eq('ipv4')
      end

      it 'raises an error if given malformed inet protocol' do
        expect { described_class.new(attrs.merge(inet_protocol: 'bad')) }.to raise_error(Puppet::Error)
      end
    end
  end

  describe 'provider' do
    let(:resource) do
      described_class.new(
        name: 'allow ssh',
        ensure: 'present',
        inet_protocol: 'ipv4',
        table: 'filter',
        chain: 'OUTPUT',
        priority: 4,
        args: '-p tcp --dport=22 -j ACCEPT'
      )
    end

    let(:provider) { resource.provider }

    it 'creates' do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--add-rule', ['ipv4', 'filter', 'OUTPUT', '4', '-p', 'tcp', '--dport=22', '-j', 'ACCEPT']], nil)
      provider.create
    end

    it 'destroys' do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--remove-rule', ['ipv4', 'filter', 'OUTPUT', '4', '-p', 'tcp', '--dport=22', '-j', 'ACCEPT']], nil)
      provider.destroy
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

  context 'autorequires' do
    # rubocop:disable RSpec/InstanceVariable
    before do
      firewalld_service = Puppet::Type.type(:service).new(name: 'firewalld')
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(firewalld_service)
    end

    let(:attrs) do
      {
        title: 'Allow SSH',
        ensure: 'present',
        table: 'filter',
        chain: 'OUTPUT',
        priority: 1,
        args: '-p tcp ---dport=22 -j ACCEPT'
      }
    end

    it 'autorequires the firewalld service' do
      resource = described_class.new(attrs)
      @catalog.add_resource(resource)

      expect(resource.autorequire.map { |rp| rp.source.to_s }).to include('Service[firewalld]')
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
