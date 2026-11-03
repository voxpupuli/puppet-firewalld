# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_direct_chain).provider(:firewall_cmd)

describe provider_class do
  let(:chains_output) { "ipv4 filter LOG_DROPS\nipv6 filter LOG_DROPS6\n" }

  before do
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--direct', '--get-all-chains'], nil).and_return(chains_output)
  end

  describe 'self.instances' do
    it 'reflects every configured direct chain' do
      found = provider_class.instances.map { |p| [p.get(:inet_protocol), p.get(:table), p.get(:name)] }
      expect(found).to contain_exactly(%w[ipv4 filter LOG_DROPS], %w[ipv6 filter LOG_DROPS6])
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by inet_protocol+table+name rather than by the Puppet resource title' do
      resource = Puppet::Type.type(:firewalld_direct_chain).new(
        name: 'Add custom chain LOG_DROPS',
        inet_protocol: 'ipv4',
        table: 'filter',
      )
      resource[:name] = 'LOG_DROPS'

      provider_class.prefetch('Add custom chain LOG_DROPS' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'does not falsely report present for an unconfigured chain' do
      resource = Puppet::Type.type(:firewalld_direct_chain).new(
        name: 'OTHER_CHAIN',
        inet_protocol: 'ipv4',
        table: 'filter',
      )

      provider_class.prefetch('OTHER_CHAIN' => resource)

      expect(resource.provider.exists?).to be false
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      resource = Puppet::Type.type(:firewalld_direct_chain).new(
        name: 'LOG_DROPS',
        inet_protocol: 'ipv4',
        table: 'filter',
      )
      provider = resource.provider
      provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(provider).not_to receive(:execute_firewall_cmd)
      expect(provider.exists?).to be true
    end

    it 'falls back to a live query when the resource was never prefetched' do
      resource = Puppet::Type.type(:firewalld_direct_chain).new(
        name: 'LOG_DROPS',
        inet_protocol: 'ipv4',
        table: 'filter',
        ensure: :absent,
      )
      provider = resource.provider

      expect(provider).to receive(:execute_firewall_cmd).with(['--direct', '--query-chain', [%w[ipv4 filter LOG_DROPS]]], nil, true, false).and_return('yes')
      expect(provider.exists?).to be true
    end
  end
end
