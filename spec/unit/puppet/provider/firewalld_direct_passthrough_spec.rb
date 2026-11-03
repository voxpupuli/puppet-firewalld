# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_direct_passthrough).provider(:firewalld_cmd)

describe provider_class do
  let(:passthroughs_output) { "ipv4 -A OUTPUT -j OUTPUT_filter\n" }

  before do
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--direct', '--get-all-passthroughs'], nil).and_return(passthroughs_output)
  end

  describe 'self.instances' do
    it 'reflects every configured direct passthrough' do
      found = provider_class.instances.map { |p| [p.get(:inet_protocol), p.get(:args)] }
      expect(found).to contain_exactly(['ipv4', '-A OUTPUT -j OUTPUT_filter'])
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by parsed args rather than by the Puppet resource title' do
      resource = Puppet::Type.type(:firewalld_direct_passthrough).new(
        name: 'Forward traffic from OUTPUT to OUTPUT_filter',
        inet_protocol: 'ipv4',
        args: '-A OUTPUT -j OUTPUT_filter',
      )

      provider_class.prefetch('Forward traffic from OUTPUT to OUTPUT_filter' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'does not falsely report present for an unconfigured passthrough' do
      resource = Puppet::Type.type(:firewalld_direct_passthrough).new(
        name: 'Forward traffic from INPUT to INPUT_filter',
        inet_protocol: 'ipv4',
        args: '-A INPUT -j INPUT_filter',
      )

      provider_class.prefetch('Forward traffic from INPUT to INPUT_filter' => resource)

      expect(resource.provider.exists?).to be false
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      resource = Puppet::Type.type(:firewalld_direct_passthrough).new(
        name: 'test',
        inet_protocol: 'ipv4',
        args: '-A OUTPUT -j OUTPUT_filter',
      )
      provider = resource.provider
      provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(provider).not_to receive(:execute_firewall_cmd)
      expect(provider.exists?).to be true
    end

    it 'falls back to a live query when the resource was never prefetched' do
      resource = Puppet::Type.type(:firewalld_direct_passthrough).new(
        name: 'test',
        inet_protocol: 'ipv4',
        args: '-A OUTPUT -j OUTPUT_filter',
        ensure: :absent,
      )
      provider = resource.provider

      expect(provider).to receive(:execute_firewall_cmd).with(
        ['--direct', '--query-passthrough', %w[ipv4 -A OUTPUT -j OUTPUT_filter]], nil, true, false
      ).and_return('yes')
      expect(provider.exists?).to be true
    end
  end
end
