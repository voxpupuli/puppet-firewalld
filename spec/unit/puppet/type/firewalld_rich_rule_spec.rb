require 'spec_helper'

describe Puppet::Type.type(:firewalld_rich_rule) do
  context 'with no params' do
    describe 'when validating attributes' do
      [  
         :family,
         :zone,
         :source,
         :service,
         :action,
         :protocol,
         :icmp_block,
         :masquerade,
         :forward_port,
         :log,
         :audit,
         :action,
         :raw_rule,
      ].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      let(:attrs) {{
        :title  => 'SSH from barny',
        :ensure => 'present',
        :zone   => 'restricted',
        :source => '192.168.1.2/32',
        :dest   => '192.168.99.2/32',
        :service => 'ssh',
        :action => 'accept'
      }}

      it 'should have :name as its namevar' do
        expect(described_class.key_attributes).to eq([:name])
      end


      it 'should default family to ipv4' do
        resource=described_class.new(attrs)
        expect(resource[:family]).to eq("ipv4")
      end

      it 'should raise an error if given malformed inet protocol' do
        expect { described_class.new(attrs.merge({:family => 'bad'})) }.to raise_error(Puppet::Error)
      end

      it 'should convert source into a hash' do
        expect(described_class.new(attrs)[:source]).to be_a(Hash)
      end

      it 'should convert dest into a hash' do
        expect(described_class.new(attrs)[:dest]).to be_a(Hash)
      end

    end

  end
end
