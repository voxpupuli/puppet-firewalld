# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_direct_rule).provider(:firewall_cmd)

describe provider_class do
  let(:rules_output) { "ipv4 filter OUTPUT 4 -p tcp --dport=22 -j ACCEPT\n" }

  before do
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--direct', '--get-all-rules'], nil).and_return(rules_output)
  end

  describe 'self.instances' do
    it 'reflects every configured direct rule' do
      found = provider_class.instances.map { |p| [p.get(:inet_protocol), p.get(:table), p.get(:chain), p.get(:priority), p.get(:args)] }
      expect(found).to contain_exactly(['ipv4', 'filter', 'OUTPUT', '4', '-p tcp --dport=22 -j ACCEPT'])
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by parsed args rather than by the Puppet resource title' do
      resource = Puppet::Type.type(:firewalld_direct_rule).new(
        name: 'Allow outgoing SSH connection',
        inet_protocol: 'ipv4',
        table: 'filter',
        chain: 'OUTPUT',
        priority: 4,
        args: '-p tcp --dport=22 -j ACCEPT',
      )

      provider_class.prefetch('Allow outgoing SSH connection' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'does not falsely report present for an unconfigured rule' do
      resource = Puppet::Type.type(:firewalld_direct_rule).new(
        name: 'Allow outgoing HTTP connection',
        inet_protocol: 'ipv4',
        table: 'filter',
        chain: 'OUTPUT',
        priority: 4,
        args: '-p tcp --dport=80 -j ACCEPT',
      )

      provider_class.prefetch('Allow outgoing HTTP connection' => resource)

      expect(resource.provider.exists?).to be false
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      resource = Puppet::Type.type(:firewalld_direct_rule).new(
        name: 'test',
        inet_protocol: 'ipv4',
        table: 'filter',
        chain: 'OUTPUT',
        priority: 4,
        args: '-p tcp --dport=22 -j ACCEPT',
      )
      provider = resource.provider
      provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(provider).not_to receive(:execute_firewall_cmd)
      expect(provider.exists?).to be true
    end

    it 'falls back to a live query when the resource was never prefetched' do
      resource = Puppet::Type.type(:firewalld_direct_rule).new(
        name: 'test',
        inet_protocol: 'ipv4',
        table: 'filter',
        chain: 'OUTPUT',
        priority: 4,
        args: '-p tcp --dport=22 -j ACCEPT',
        ensure: :absent,
      )
      provider = resource.provider

      expect(provider).to receive(:execute_firewall_cmd).with(
        ['--direct', '--query-rule', %w[ipv4 filter OUTPUT 4 -p tcp --dport=22 -j ACCEPT]], nil, true, false
      ).and_return('yes')
      expect(provider.exists?).to be true
    end
  end
end
