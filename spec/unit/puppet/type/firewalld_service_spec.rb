# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'
RSpec.configure { |c| c.mock_with :rspec }

describe Puppet::Type.type(:firewalld_service) do
  before do
    allow_any_instance_of(Puppet::Provider::Firewalld).to receive(:state).and_return(true)
  end

  context 'with no params' do
    describe 'when validating attributes' do
      %i[name service zone].each do |param|
        it "has a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      it 'has :name as its namevar' do
        expect(described_class.key_attributes).to eq([:name])
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
      resource = described_class.new(name: 'test', service: 'test', zone: 'test')
      @catalog.add_resource(resource)

      expect(resource.autorequire.map { |rp| rp.source.to_s }).to include('Service[firewalld]')
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
