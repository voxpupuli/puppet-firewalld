# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_port).provider(:firewall_cmd)

describe provider_class do
  let(:zones_output) do
    <<~DATA
      public (active)
        target: default
        services:
        ports: 8080/tcp
        rich rules:

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
        ports: 443/tcp
        rich rules:
    DATA
  end

  before do
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-zones'], nil).and_return(zones_output)
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-policies'], nil).and_return(policies_output)
  end

  describe 'self.instances' do
    it 'reflects ports actually bound to zones' do
      found = provider_class.instances.select { |p| p.get(:zone) == 'public' }.map { |p| [p.get(:port), p.get(:protocol)] }
      expect(found).to contain_exactly(%w[8080 tcp])
    end

    it 'reflects ports actually bound to policies' do
      found = provider_class.instances.select { |p| p.get(:policy) == 'anytorestricted' }.map { |p| [p.get(:port), p.get(:protocol)] }
      expect(found).to contain_exactly(%w[443 tcp])
    end

    it 'does not include a zone with no ports bound' do
      found = provider_class.instances.select { |p| p.get(:zone) == 'work' }
      expect(found).to be_empty
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by port+protocol+zone rather than by the Puppet resource title' do
      resource = Puppet::Type.type(:firewalld_port).new(
        name: 'Open port 8080 in the public Zone',
        port: 8080,
        protocol: 'tcp',
        zone: 'public',
      )

      provider_class.prefetch('Open port 8080 in the public Zone' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'does not falsely report present when the zone has a different port bound' do
      resource = Puppet::Type.type(:firewalld_port).new(
        name: 'port 9090 on public',
        port: 9090,
        protocol: 'tcp',
        zone: 'public',
      )

      provider_class.prefetch('port 9090 on public' => resource)

      expect(resource.provider.exists?).to be false
    end

    it 'checks policies when the resource uses a policy instead of a zone' do
      resource = Puppet::Type.type(:firewalld_port).new(
        name: 'port 443 on policy',
        port: 443,
        protocol: 'tcp',
        policy: 'anytorestricted',
      )

      provider_class.prefetch('port 443 on policy' => resource)

      expect(resource.provider.exists?).to be true
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      resource = Puppet::Type.type(:firewalld_port).new(
        name: 'test',
        port: 8080,
        protocol: 'tcp',
        zone: 'public',
      )
      provider = resource.provider
      provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(provider).not_to receive(:execute_firewall_cmd)
      expect(provider).not_to receive(:execute_firewall_cmd_policy)
      expect(provider.exists?).to be true
    end

    # Regression test: firewalld_zone's purge_ports constructs ad-hoc
    # firewalld_port resources outside the normal catalog/prefetch flow and
    # calls provider.exists? directly on them to decide whether to purge.
    # Those resources never go through self.prefetch, so exists? must fall
    # back to a live query rather than assume absent.
    it 'falls back to a live query when the resource was never prefetched' do
      resource = Puppet::Type.type(:firewalld_port).new(
        name: 'test',
        port: 8080,
        protocol: 'tcp',
        zone: 'public',
        ensure: :absent,
      )
      provider = resource.provider

      expect(provider).to receive(:execute_firewall_cmd).with(['--query-port', [['8080/tcp']]], 'public', true, false).and_return(double(exitstatus: 0))
      expect(provider.exists?).to be true
    end
  end
end
