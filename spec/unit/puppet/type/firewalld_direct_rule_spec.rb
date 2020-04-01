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
