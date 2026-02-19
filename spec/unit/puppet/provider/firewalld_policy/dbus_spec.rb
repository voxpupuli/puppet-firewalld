# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_policy).provider(:dbus)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_policy).new(
      ensure: :present,
      name: 'public2restricted',
      description: 'Public to restricted',
      ingress_zones: ['public'],
      egress_zones: ['restricted'],
      provider: described_class.name
    )
  end
  let(:provider) { resource.provider }

  before do
    @policy_double = double()
    allow(provider).to receive(:dbus_resource).and_return(@policy_double)

    allow(@policy_double).to receive(:[]).with('name')

    @config_interface_double = double()
    allow(Puppet::Provider::FirewalldDbus).to receive(:firewalld_config_interface).and_return(@config_interface_double)
    allow(provider).to receive(:reload_firewall)
  end

  describe 'when creating policy' do
    context 'with name public2restricted' do
      it 'creates new policy' do
        expect(resource).to receive(:[]).with(:name).and_return('public2restricted').at_least(:once)
        expect(resource).to receive(:[]).with(:target).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:ingress_zones).and_return(['public']).at_least(:once)
        expect(resource).to receive(:[]).with(:egress_zones).and_return(['restricted']).at_least(:once)
        expect(resource).to receive(:[]).with(:priority).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_blocks).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:description).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:short).and_return('public2restricted').at_least(:once)

        expect(described_class).to receive(:dbus_interface).with(object: 'policy', interface: 'org.fedoraproject.FirewallD1.config.policy').and_return(@policy_double)
        expect(@config_interface_double).to receive(:addPolicy).with('public2restricted', { 'ingress_zones' => ['public'], 'egress_zones' => ['restricted'], 'short' => 'public2restricted' }).and_return("policy")

        provider.create
      end
    end
  end

  describe 'when modifying description' do
    context 'type' do
      it 'stores updated description' do
        expect(resource).to receive(:[]).with(:name).and_return('public2restricted').at_least(:once)
        expect(resource).to receive(:[]).with(:target).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:ingress_zones).and_return(['public']).at_least(:once)
        expect(resource).to receive(:[]).with(:egress_zones).and_return(['restricted']).at_least(:once)
        expect(resource).to receive(:[]).with(:priority).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:icmp_blocks).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:description).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:short).and_return('public2restricted').at_least(:once)

        expect(described_class).to receive(:dbus_interface).with(object: 'policy', interface: 'org.fedoraproject.FirewallD1.config.policy').and_return(@policy_double)
        expect(@config_interface_double).to receive(:addPolicy).with('public2restricted', { 'ingress_zones' => ['public'], 'egress_zones' => ['restricted'], 'short' => 'public2restricted' }).and_return("policy")

        provider.create

        expect(@policy_double).to receive(:update).with({ 'description' => 'Modified description' })

        provider.description = 'Modified description'
        provider.flush
      end
    end
  end
end
