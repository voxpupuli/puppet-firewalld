require 'spec_helper'

describe Puppet::Type.type(:firewalld_direct_chain) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true) # rubocop:disable RSpec/AnyInstance
  end

  context 'with no params' do
    describe 'when validating attributes' do
      [:name, :inet_protocol, :table].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      it 'has :name, :inet_protocol and :table as its namevars' do
        expect(described_class.key_attributes).to eq([:name, :inet_protocol, :table])
      end

      it 'uses the title as the name when non-delimited' do
        resource = described_class.new(title: 'LOG_DROPS', table: 'filter')
        expect(resource.name).to eq('LOG_DROPS')
      end

      context 'colon delimited title pattern' do
        let(:resource) { described_class.new(title: 'ipv4:filter:LOG_DROPS') }

        it 'sets resource `name` correctly' do
          expect(resource.name).to eq('LOG_DROPS')
        end
        it 'sets resource `table` parameter correctly' do
          expect(resource[:table]).to eq('filter')
        end
        it 'sets resource `inet_protocol` parameter correctly' do
          expect(resource[:inet_protocol]).to eq('ipv4')
        end
      end

      it 'defaults inet_protocol to ipv4' do
        resource = described_class.new(title: 'LOG_DROPS', table: 'filter')
        expect(resource[:inet_protocol]).to eq('ipv4')
      end

      it 'raises an error if given malformed inet protocol' do
        expect { described_class.new(title: '4vpi:filter:LOG_DROPS') }.to raise_error(Puppet::Error)
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
      resource = described_class.new(name: 'ipv4:filter:LOG_DROPS')
      @catalog.add_resource(resource)

      expect(resource.autorequire.map { |rp| rp.source.to_s }).to include('Service[firewalld]')
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
