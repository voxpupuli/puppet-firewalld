require 'spec_helper'

describe Puppet::Type.type(:firewalld_port) do
  context 'with no params' do
    describe 'when validating attributes' do
      [:name, :zone, :port].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      it 'should have :name as its namevar' do
        expect(described_class.key_attributes).to eq([:name])
      end
    end

    describe 'port' do
      port = { 'port' => 8080, 'protocol' => 'tcp' }
      it "should accept '#{port}'" do
        expect do
          described_class.new(
            name: 'Allow port 8080',
            zone: 'public',
            port: port
          ).to_not raise_error
        end
      end
    end
  end
end
