# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_service).provider(:firewall_cmd)

describe provider_class do
  let(:zones_output) do
    <<~DATA
      public (active)
        target: default
        services: ssh dhcpv6-client
        ports:
        rich rules:

      work
        target: default
        services:
        ports: 8080/tcp
        rich rules:
    DATA
  end

  let(:policies_output) do
    <<~DATA
      anytorestricted (active)
        target: CONTINUE
        services: nfs
        ports:
        rich rules:
    DATA
  end

  describe 'self.instances' do
    before do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-zones'], nil).and_return(zones_output)
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-policies'], nil).and_return(policies_output)
    end

    it 'reflects services actually bound to zones, not the predefined service catalog' do
      found = provider_class.instances.select { |p| p.get(:zone) == 'public' }.map { |p| p.get(:service) }
      expect(found).to contain_exactly('ssh', 'dhcpv6-client')
    end

    it 'reflects services actually bound to policies' do
      found = provider_class.instances.select { |p| p.get(:policy) == 'anytorestricted' }.map { |p| p.get(:service) }
      expect(found).to contain_exactly('nfs')
    end

    it 'does not include a zone with no services bound' do
      found = provider_class.instances.select { |p| p.get(:zone) == 'work' }
      expect(found).to be_empty
    end
  end

  describe 'self.prefetch' do
    before do
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-zones'], nil).and_return(zones_output)
      allow(provider_class).to receive(:execute_firewall_cmd).with(['--list-all-policies'], nil).and_return(policies_output)
    end

    # This is a regression test: the resource title is an arbitrary string
    # (eg. "Allow SSH from the external zone"), not the firewalld service
    # name, which lives in the separate `service` parameter. prefetch must
    # match on (service, zone) / (service, policy), not on the title.
    it 'matches resources by service+zone rather than by the Puppet resource title' do
      resource = Puppet::Type.type(:firewalld_service).new(
        name: 'Allow SSH from the external zone',
        service: 'ssh',
        zone: 'public',
      )

      provider_class.prefetch('Allow SSH from the external zone' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'does not falsely report present when the zone has a different service bound' do
      resource = Puppet::Type.type(:firewalld_service).new(
        name: 'nfs on public',
        service: 'nfs',
        zone: 'public',
      )

      provider_class.prefetch('nfs on public' => resource)

      expect(resource.provider.exists?).to be false
    end

    it 'checks policies when the resource uses a policy instead of a zone' do
      resource = Puppet::Type.type(:firewalld_service).new(
        name: 'nfs on policy',
        service: 'nfs',
        policy: 'anytorestricted',
      )

      provider_class.prefetch('nfs on policy' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'only queries --list-all-policies when at least one resource uses a policy' do
      resource = Puppet::Type.type(:firewalld_service).new(
        name: 'ssh on public',
        service: 'ssh',
        zone: 'public',
      )

      expect(provider_class).not_to receive(:policy_service_map)

      provider_class.prefetch('ssh on public' => resource)
    end

    it 'only queries --list-all-zones when at least one resource uses a zone' do
      resource = Puppet::Type.type(:firewalld_service).new(
        name: 'nfs on policy',
        service: 'nfs',
        policy: 'anytorestricted',
      )

      expect(provider_class).not_to receive(:zone_service_map)

      provider_class.prefetch('nfs on policy' => resource)
    end
  end

  describe '#exists?' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      resource = Puppet::Type.type(:firewalld_service).new(
        name: 'test',
        service: 'ssh',
        zone: 'public',
      )
      provider = resource.provider
      provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(provider).not_to receive(:execute_firewall_cmd)
      expect(provider).not_to receive(:execute_firewall_cmd_policy)
      expect(provider.exists?).to be true
    end

    # Regression test: firewalld_zone's purge_services constructs ad-hoc
    # firewalld_service resources outside the normal catalog/prefetch flow
    # and calls provider.exists? directly on them to decide whether to
    # purge. Those resources never go through self.prefetch, so exists?
    # must fall back to a live query rather than assume absent.
    it 'falls back to a live query when the resource was never prefetched' do
      resource = Puppet::Type.type(:firewalld_service).new(
        name: 'test',
        service: 'ssh',
        zone: 'public',
        ensure: :absent,
      )
      provider = resource.provider

      expect(provider).to receive(:execute_firewall_cmd).with(['--list-services']).and_return('ssh dhcpv6-client')
      expect(provider.exists?).to be true
    end
  end
end
