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

  describe '#exists?' do
    context 'when firewalld is not available' do
      before do
        allow(provider).to receive(:available?).and_return(false)
      end

      it 'returns false without calling firewall-cmd' do
        expect(provider).not_to receive(:execute_firewall_cmd)
        expect(provider.exists?).to be false
      end
    end

    context 'when a zone is set' do
      before do
        allow(provider).to receive(:available?).and_return(true)
      end

      context 'and the zone exists with the service present' do
        before do
          allow(provider).to receive(:execute_firewall_cmd)
            .with(['--list-services'], 'public', true, false)
            .and_return(double(exitstatus: 0, split: %w[ssh http https]))
        end

        it 'returns true' do
          expect(provider.exists?).to be true
        end
      end

      context 'and the zone exists but the service is absent' do
        before do
          allow(provider).to receive(:execute_firewall_cmd)
            .with(['--list-services'], 'public', true, false)
            .and_return(double(exitstatus: 0, split: %w[http https]))
        end

        it 'returns false' do
          expect(provider.exists?).to be false
        end
      end

      context 'and the zone does not exist (e.g. during noop when zone is being created)' do
        before do
          allow(provider).to receive(:execute_firewall_cmd)
            .with(['--list-services'], 'public', true, false)
            .and_return(double(exitstatus: 2))
        end

        it 'returns false without raising an error' do
          expect { provider.exists? }.not_to raise_error
        end

        it 'returns false' do
          expect(provider.exists?).to be false
        end
      end
    end
  end
end
