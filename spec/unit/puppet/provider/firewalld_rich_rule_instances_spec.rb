# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_rich_rule).provider(:firewall_cmd)

describe provider_class do
  let(:rule_str) { 'rule family="ipv4" source address="10.0.1.2/24" service name="ssh" accept' }

  let(:zones_output) do
    <<~DATA
      public (active)
        target: default
        services:
        ports:
        rich rules:
      \t#{rule_str}

      work
        target: default
        services:
        ports:
        rich rules:
    DATA
  end

  let(:policies_output) do
    <<~DATA
      anytorestricted (active)
        target: CONTINUE
        services:
        ports:
        rich rules:
      \trule family="ipv4" source address="10.0.2.0/24" service name="https" accept
    DATA
  end

  before do
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-zones'], nil).and_return(zones_output)
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-policies'], nil).and_return(policies_output)
  end

  describe 'self.instances' do
    it 'reflects rich rules actually bound to zones' do
      found = provider_class.instances.select { |p| p.get(:zone) == 'public' }.map { |p| p.get(:raw_rule) }
      expect(found).to contain_exactly(rule_str)
    end

    it 'reflects rich rules actually bound to policies' do
      found = provider_class.instances.select { |p| p.get(:policy) == 'anytorestricted' }.map { |p| p.get(:raw_rule) }
      expect(found).to contain_exactly('rule family="ipv4" source address="10.0.2.0/24" service name="https" accept')
    end

    it 'does not include a zone with no rich rules bound' do
      found = provider_class.instances.select { |p| p.get(:zone) == 'work' }
      expect(found).to be_empty
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by built rule text rather than by the Puppet resource title' do
      resource = Puppet::Type.type(:firewalld_rich_rule).new(
        name: 'Accept ssh from barny',
        zone: 'public',
        family: 'ipv4',
        source: '10.0.1.2/24',
        service: 'ssh',
        action: 'accept',
      )

      provider_class.prefetch('Accept ssh from barny' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'does not falsely report present when the zone has a different rule' do
      resource = Puppet::Type.type(:firewalld_rich_rule).new(
        name: 'Accept http',
        zone: 'public',
        family: 'ipv4',
        source: '10.0.9.9/32',
        service: 'http',
        action: 'accept',
      )

      provider_class.prefetch('Accept http' => resource)

      expect(resource.provider.exists?).to be false
    end

    it 'checks policies when the resource uses a policy instead of a zone' do
      resource = Puppet::Type.type(:firewalld_rich_rule).new(
        name: 'https on policy',
        policy: 'anytorestricted',
        family: 'ipv4',
        source: '10.0.2.0/24',
        service: 'https',
        action: 'accept',
      )

      provider_class.prefetch('https on policy' => resource)

      expect(resource.provider.exists?).to be true
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      resource = Puppet::Type.type(:firewalld_rich_rule).new(
        name: 'test',
        zone: 'public',
        family: 'ipv4',
        source: '10.0.1.2/24',
        service: 'ssh',
        action: 'accept',
      )
      provider = resource.provider
      provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(provider).not_to receive(:execute_firewall_cmd)
      expect(provider).not_to receive(:execute_firewall_cmd_policy)
      expect(provider.exists?).to be true
    end

    # Regression test: firewalld_zone's purge_rich_rules constructs ad-hoc
    # firewalld_rich_rule resources outside the normal catalog/prefetch flow
    # and calls provider.exists? directly on them to decide whether to
    # purge. Those resources never go through self.prefetch, so exists?
    # must fall back to a live query rather than assume absent.
    it 'falls back to a live query when the resource was never prefetched' do
      resource = Puppet::Type.type(:firewalld_rich_rule).new(
        name: 'test',
        zone: 'public',
        raw_rule: rule_str,
        ensure: :absent,
      )
      provider = resource.provider

      expect(provider).to receive(:execute_firewall_cmd).with(['--query-rich-rule', rule_str], 'public', true, false).and_return(double(exitstatus: 0))
      expect(provider.exists?).to be true
    end
  end
end
