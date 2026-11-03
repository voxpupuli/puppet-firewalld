# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_custom_service).provider(:firewall_cmd)

describe provider_class do
  require 'rexml/document'
  include REXML

  before do
    allow_any_instance_of(provider_class).to receive(:execute_firewall_cmd).and_return(double(exitstatus: 0))
  end

  let(:provider) { resource.provider }

  context 'simplest resource creation' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :present,
        name: 'test_service',
      )
    end

    it 'creates the service' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--new-service', resource[:name]], nil)
      provider.create
    end

    it 'retrieves and formats the system ports' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--get-ports'], nil).and_return('123/tcp 456/udp')

      expect(provider.ports).to eq([
                                     {
                                       'port' => '123',
                                       'protocol' => 'tcp',
                                     },
                                     {
                                       'port' => '456',
                                       'protocol' => 'udp',
                                     },
                                   ])
    end

    it 'retrieves and formats the system destinations' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--get-destinations'], nil).and_return('ipv4:1.2.3.4/23 ipv6:::1')

      expect(provider.ipv4_destination).to eq('1.2.3.4/23')
      expect(provider.ipv6_destination).to eq('::1')
    end

    it 'exists when returned by the system' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return("#{resource[:name]} foo bar baz")
      expect(provider).to receive(:execute_firewall_cmd).with(['--path-service', resource[:name]], nil).and_return('/etc/foo_bar_baz.xml')

      expect(provider.exists?).to be true
    end

    it 'does not exist when not returned by the system' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return('foo bar baz')

      expect(provider.exists?).to be false
    end
  end

  context 'resource deletion' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :absent,
        name: 'test_service',
      )
    end

    it 'runs delete-service when it is not a builtin' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--delete-service', resource[:name]], nil)
      provider.destroy
    end

    it 'runs load-service-defaults when it is a builtin' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--delete-service', resource[:name]], nil).and_raise(Puppet::ExecutionFailure, 'nooooooooooooo')
      expect(provider).to receive(:execute_firewall_cmd).with(['--load-service-default', resource[:name]], nil)

      provider.destroy
    end
  end

  context 'all parameters populated' do
    let(:resource) do
      Puppet::Type.type(:firewalld_custom_service).new(
        ensure: :present,
        name: 'test_service',
        short: 'Short Name',
        description: 'This is a description',
        ports: [
          '123/tcp',
          '234/udp',
          { 'port' => 345, 'protocol' => 'udp' },
          { 'port' => '456', 'protocol' => 'tcp' },
          { 'protocol' => 'dccp' },
        ],
        protocols: %w[foo bar baz],
        modules: %w[nf_thingy nf_other_thingy],
        ipv4_destination: '1.2.3.0/24',
        ipv6_destination: '::1',
      )
    end

    it 'creates the service' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--new-service', resource[:name]], nil)
      expect(provider).to receive(:short=).with(resource[:short])
      expect(provider).to receive(:description=).with(resource[:description])
      expect(provider).to receive(:ports).and_return(true)
      expect(provider).to receive(:ports=).with(resource[:ports])
      expect(provider).to receive(:protocols).and_return(true)
      expect(provider).to receive(:protocols=).with(resource[:protocols])
      expect(provider).to receive(:modules).and_return(true)
      expect(provider).to receive(:modules=).with(resource[:modules])
      expect(provider).to receive(:ipv4_destination=).with(resource[:ipv4_destination])
      expect(provider).to receive(:ipv6_destination=).with(resource[:ipv6_destination])

      provider.create
    end

    it 'sets the short description' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-short', resource[:short]], nil)
      provider.short = resource[:short]
    end

    it 'sets the full description' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-description', resource[:description]], nil)
      provider.description = resource[:description]
    end

    # Multiple added/removed ports, protocols, and modules are each batched
    # into a single firewall-cmd call (one for additions, one for removals)
    # instead of one call per value, since --add-X/--remove-X accept being
    # repeated in one invocation. Adds and removes can never be combined in
    # the same call: firewall-cmd's argument parsing only acts on the first
    # recognized action flag it sees.
    context 'setting ports' do
      it 'works without existing ports' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-port', '123/tcp', '--add-port', '234/udp', '--add-port', '345/udp', '--add-port', '456/tcp'], nil
        )

        ports = []
        provider.instance_variable_set('@property_hash', ports: ports)
        provider.ports = resource[:ports]
      end

      it 'works with disjoint existing ports' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-port', '123/tcp', '--add-port', '234/udp', '--add-port', '345/udp', '--add-port', '456/tcp'], nil
        )

        ports = [
          { 'port' => '789', 'protocol' => 'udp' },
          { 'port' => '8910', 'protocol' => 'tcp' },
        ]
        provider.instance_variable_set('@property_hash', ports: ports)

        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--remove-port', '789/udp', '--remove-port', '8910/tcp'], nil
        )

        provider.ports = resource[:ports]
      end

      it 'works with overlapping existing ports' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-port', '123/tcp', '--add-port', '234/udp', '--add-port', '456/tcp'], nil
        )

        ports = [
          { 'port' => '345', 'protocol' => 'udp' },
          { 'port' => '8910', 'protocol' => 'tcp' },
        ]
        provider.instance_variable_set('@property_hash', ports: ports)

        expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-port', '8910/tcp'], nil)

        provider.ports = resource[:ports]
      end
    end

    context 'setting protocols' do
      it 'works without existing protocols' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-protocol', 'foo', '--add-protocol', 'bar', '--add-protocol', 'baz', '--add-protocol', 'dccp'], nil
        )

        protocols = []
        provider.instance_variable_set('@property_hash', protocols: protocols)
        provider.protocols = resource[:protocols]
      end

      it 'works with disjoint existing protocols' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-protocol', 'foo', '--add-protocol', 'bar', '--add-protocol', 'baz', '--add-protocol', 'dccp'], nil
        )

        protocols = %w[
          icmp
          test
        ]
        provider.instance_variable_set('@property_hash', protocols: protocols)

        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--remove-protocol', 'icmp', '--remove-protocol', 'test'], nil
        )

        provider.protocols = resource[:protocols]
      end

      it 'works with overlapping existing protocols' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-protocol', 'foo', '--add-protocol', 'baz', '--add-protocol', 'dccp'], nil
        )

        protocols = %w[
          bar
          icmp
        ]
        provider.instance_variable_set('@property_hash', protocols: protocols)

        expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-protocol', 'icmp'], nil)

        provider.protocols = resource[:protocols]
      end
    end

    context 'setting modules' do
      it 'works without existing modules' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-module', 'nf_thingy', '--add-module', 'nf_other_thingy'], nil
        )

        modules = []
        provider.instance_variable_set('@property_hash', modules: modules)
        provider.modules = resource[:modules]
      end

      it 'works with disjoint existing modules' do
        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--add-module', 'nf_thingy', '--add-module', 'nf_other_thingy'], nil
        )

        modules = %w[
          nf_stuff
          nf_bob
        ]
        provider.instance_variable_set('@property_hash', modules: modules)

        expect(provider).to receive(:execute_firewall_cmd).with(
          ['--service', resource[:name], '--remove-module', 'nf_stuff', '--remove-module', 'nf_bob'], nil
        )

        provider.modules = resource[:modules]
      end

      it 'works with overlapping existing modules' do
        expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--add-module', 'nf_other_thingy'], nil)

        modules = %w[
          nf_thingy
          nf_bob
        ]
        provider.instance_variable_set('@property_hash', modules: modules)

        expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--remove-module', 'nf_bob'], nil)

        provider.modules = resource[:modules]
      end
    end

    it 'sets the ipv4_destination' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-destination', "ipv4:#{resource[:ipv4_destination]}"], nil)
      provider.ipv4_destination = resource[:ipv4_destination]
    end

    it 'sets the ipv6_destination' do
      expect(provider).to receive(:execute_firewall_cmd).with(['--service', resource[:name], '--set-destination', "ipv6:#{resource[:ipv6_destination]}"], nil)
      provider.ipv6_destination = resource[:ipv6_destination]
    end
  end

  describe 'self.instances' do
    it 'reflects every known service name' do
      expect(provider_class).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return('ssh test_service other')
      expect(provider_class.instances.map(&:name)).to contain_exactly('ssh', 'test_service', 'other')
    end
  end

  describe 'self.prefetch' do
    it 'matches resources by name, since the custom_service namevar maps to the firewalld service name' do
      resource = Puppet::Type.type(:firewalld_custom_service).new(name: 'test_service')

      expect(provider_class).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return('test_service foo bar')
      expect(provider_class).to receive(:execute_firewall_cmd).with(['--path-service', 'test_service'], nil).and_return('/etc/test_service.xml')

      provider_class.prefetch('test_service' => resource)

      expect(resource.provider.exists?).to be true
    end

    it 'does not falsely report present for an unconfigured service' do
      resource = Puppet::Type.type(:firewalld_custom_service).new(name: 'missing_service')

      expect(provider_class).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return('foo bar')

      provider_class.prefetch('missing_service' => resource)

      expect(resource.provider.exists?).to be false
    end

    it 'reports absent for a builtin service when ensure is absent' do
      resource = Puppet::Type.type(:firewalld_custom_service).new(name: 'ssh', ensure: :absent)

      expect(provider_class).to receive(:execute_firewall_cmd).with(['--get-services'], nil).and_return('ssh foo bar')
      expect(provider_class).to receive(:execute_firewall_cmd).with(['--path-service', 'ssh'], nil).and_return('/usr/lib/firewalld/services/ssh.xml')

      provider_class.prefetch('ssh' => resource)

      expect(resource.provider.exists?).to be false
    end
  end

  describe '#exists? with a prefetched property_hash' do
    it 'relies on the prefetched property_hash rather than shelling out' do
      resource = Puppet::Type.type(:firewalld_custom_service).new(name: 'test_service')
      resource.provider.instance_variable_set(:@property_hash, ensure: :present)

      expect(resource.provider).not_to receive(:execute_firewall_cmd)
      expect(resource.provider.exists?).to be true
    end
  end
end
