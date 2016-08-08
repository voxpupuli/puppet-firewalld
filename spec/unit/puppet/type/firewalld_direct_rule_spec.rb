require 'spec_helper'

describe Puppet::Type.type(:firewalld_direct_rule) do
  context 'with no params' do
    describe 'when validating attributes' do
      [:inet_protocol, :args, :table, :chain, :priority].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      let(:attrs) {{
        :title  => 'Allow SSH',
        :ensure => 'present',
        :table => 'filter',
        :chain => 'OUTPUT',
        :priority => 1,
        :args => '-p tcp ---dport=22 -j ACCEPT'
      }}

      it 'should have :name as its namevar' do
        expect(described_class.key_attributes).to eq([:name])
      end


      it 'should default inet_protocol to ipv4' do
        resource=described_class.new(attrs)
        expect(resource[:inet_protocol]).to eq("ipv4")
      end

      it 'should raise an error if given malformed inet protocol' do
        expect { described_class.new(attrs.merge({:inet_protocol => 'bad'})) }.to raise_error(Puppet::Error)
      end

    end

  end
end
