# frozen_string_literal: true

RSpec.shared_examples 'a noop-safe firewalld provider' do |provider_class|
  context 'when firewalld is not available' do
    before do
      allow(provider_class).to receive(:available?).and_return(false)
    end

    describe '.instances' do
      it 'returns an empty array without calling firewall-cmd' do
        expect(provider_class).not_to receive(:execute_firewall_cmd)
        expect(provider_class.instances).to eq([])
      end
    end

    describe '.prefetch' do
      it 'does not call firewall-cmd' do
        expect(provider_class).not_to receive(:execute_firewall_cmd)
        provider_class.prefetch('noop' => noop_resource)
      end
    end

    describe '#exists?' do
      it 'returns false without calling firewall-cmd' do
        provider = provider_class.new(noop_resource)

        allow(provider).to receive(:available?).and_return(false)
        expect(provider).not_to receive(:execute_firewall_cmd)
        expect(provider.exists?).to be false
      end
    end
  end
end
