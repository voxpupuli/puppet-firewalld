# frozen_string_literal: true

require 'spec_helper'

# Trigger autoloading of the shared base provider class.
Puppet::Type.type(:firewalld_zone).provider(:firewall_cmd)

describe Puppet::Provider::Firewalld do
  describe '.parse_list_all' do
    it 'parses services, ports and rich rules per zone' do
      output = <<~DATA
        public (default, active)
          target: default
          icmp-block-inversion: no
          interfaces: eth0
          sources:
          services: ssh dhcpv6-client
          ports: 8080/tcp 53/udp
          protocols:
          forward: no
          masquerade: no
          forward-ports:
          source-ports:
          icmp-blocks:
          rich rules:
        \trule family="ipv4" source address="10.0.0.0/24" accept

        work (active)
          target: default
          icmp-block-inversion: no
          interfaces:
          sources:
          services:
          ports:
          protocols:
          forward: no
          masquerade: no
          forward-ports:
          source-ports:
          icmp-blocks:
          rich rules:

      DATA

      result = described_class.parse_list_all(output)

      expect(result['public']['services']).to eq(%w[ssh dhcpv6-client])
      expect(result['public']['ports']).to eq([{ 'port' => '8080', 'protocol' => 'tcp' }, { 'port' => '53', 'protocol' => 'udp' }])
      expect(result['public']['rich_rules']).to eq(['rule family="ipv4" source address="10.0.0.0/24" accept'])
      expect(result['work']['services']).to eq([])
      expect(result['work']['rich_rules']).to eq([])
    end

    it 'does not treat forward-ports continuation lines as rich rules' do
      output = <<~DATA
        mixed (active)
          target: default
          icmp-block-inversion: no
          interfaces: eth0
          sources:
          services:
          ports:
          protocols:
          forward: yes
          masquerade: no
          forward-ports:
        \tport=8080:proto=tcp:toport=80:toaddr=10.0.0.5
          source-ports:
          icmp-blocks:
          rich rules:
        \trule family="ipv4" source address="10.0.0.0/24" accept

      DATA

      result = described_class.parse_list_all(output)

      expect(result['mixed']['rich_rules']).to eq(['rule family="ipv4" source address="10.0.0.0/24" accept'])
    end

    it 'parses policy output, which has no interfaces/sources fields' do
      output = <<~DATA
        anytorestricted (active)
          disable: no
          priority: -1
          target: CONTINUE
          ingress-zones: ANY
          egress-zones: restricted
          services: nfs
          ports:
          protocols:
          masquerade: no
          forward-ports:
          source-ports:
          icmp-blocks:
          rich rules:

      DATA

      result = described_class.parse_list_all(output)

      expect(result['anytorestricted']['services']).to eq(['nfs'])
    end

    it 'returns an empty hash for empty output' do
      expect(described_class.parse_list_all('')).to eq({})
    end
  end
end
