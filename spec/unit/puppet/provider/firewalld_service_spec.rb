# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:firewalld_service).provider(:firewall_cmd) do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_service).new(
      ensure: :present,
      name: 'ssh',
      zone: 'public',
      provider: described_class.name,
    )
  end
  let(:provider) { resource.provider }

  before do
    allow(described_class).to receive(:execute_firewall_cmd).with(['--state'], nil, nil, false, false, false).and_return(double(exitstatus: 0))
    allow(described_class).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return('ssh http https')
  end

  describe 'self.instances' do
    context 'when firewalld is not available' do
      before do
        allow(described_class).to receive(:available?).and_return(false)
      end

      it 'returns an empty array without calling firewall-cmd' do
        expect(described_class).not_to receive(:execute_firewall_cmd).with(['--get-services'], nil)
        expect(described_class.instances).to eq([])
      end
    end

    context 'when firewalld is available' do
      before do
        allow(described_class).to receive(:available?).and_return(true)
      end

      it 'returns instances for each available service' do
        instances = described_class.instances
        expect(instances.map(&:name)).to include('ssh', 'http', 'https')
      end
    end
  end
end
