require 'spec_helper'

describe Puppet::Type.type(:firewalld_service) do
  context 'with no params' do
    describe 'when validating attributes' do
      [:name, :service, :zone].each do |param|
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
  end
end
