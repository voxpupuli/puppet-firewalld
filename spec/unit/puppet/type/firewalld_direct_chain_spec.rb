require 'spec_helper'

describe Puppet::Type.type(:firewalld_direct_chain) do
  context 'with no params' do
    describe 'when validating attributes' do
      [:name, :inet_protocol, :table].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      it 'should have :name, :inet_protocol and :table as its namevars' do
        expect(described_class.key_attributes).to eq([:name, :inet_protocol, :table])
      end

      it 'should use the title as the name when non-delimited' do
        resource=described_class.new(:title => 'LOG_DROPS', :table => 'filter')
        expect(resource.name).to eq('LOG_DROPS')
      end

      it 'should split the title pattern if comma delimited' do
        resource=described_class.new(:title => 'ipv4:filter:LOG_DROPS')
        expect(resource.name).to eq('LOG_DROPS')
        expect(resource[:table]).to eq('filter')
        expect(resource[:inet_protocol]).to eq("ipv4")
      end

      it 'should default inet_protocol to ipv4' do
        resource=described_class.new(:title => 'LOG_DROPS', :table => 'filter')
        expect(resource[:inet_protocol]).to eq("ipv4")
      end

      it 'should raise an error if given malformed inet protocol' do
        expect { described_class.new(:title => '4vpi:filter:LOG_DROPS') }.to raise_error(Puppet::Error)
      end

    end

  end
end
