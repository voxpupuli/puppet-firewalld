# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_direct_purge).provider(:firewall_cmd)

describe provider_class do
  describe '#get_instances_of' do
    it 'returns an empty array without calling firewall-cmd when firewalld is not available' do
      resource = Puppet::Type.type(:firewalld_direct_purge).new(name: 'chain')
      provider = resource.provider

      allow(provider).to receive(:available?).and_return(false)
      expect(provider).not_to receive(:execute_firewall_cmd)
      expect(provider.get_instances_of(:chain)).to eq([])
    end
  end
end
