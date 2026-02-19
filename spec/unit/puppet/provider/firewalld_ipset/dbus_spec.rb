# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_ipset).provider(:dbus)

describe provider_class do
  let(:resource) do
    @resource = Puppet::Type.type(:firewalld_ipset).new(
      ensure: :present,
      name: 'white',
      type: 'hash:net',
      entries: ['8.8.8.8'],
      provider: described_class.name
    )
  end
  let(:provider) { resource.provider }

  before do
    @iface_double = double()
    allow(provider).to receive(:dbus_ipset).and_return(@iface_double)

    @config_interface_double = double()
    allow(Puppet::Provider::FirewalldDbus).to receive(:firewalld_config_interface).and_return(@config_interface_double)

    allow(@config_interface_double).to receive(:listIPSets).and_return(['white', 'black'])

    white_double = double()
    allow(Puppet::Provider::FirewalldDbus).to receive(:dbus_interface).with(object: 'white', interface: 'org.fedoraproject.FirewallD1.config.ipset').and_return(white_double)
    black_double = double()
    allow(Puppet::Provider::FirewalldDbus).to receive(:dbus_interface).with(object: 'black', interface: 'org.fedoraproject.FirewallD1.config.ipset').and_return(black_double)

    allow(white_double).to receive(:[]).with('name').and_return('white')
    allow(white_double).to receive(:getType).and_return("hash:ip")
    allow(white_double).to receive(:getOptions).and_return({ 'maxelem' => '200', 'family' => 'inet6' })
    allow(black_double).to receive(:[]).with('name').and_return('black')
    allow(black_double).to receive(:getType).and_return("hash:ip")
    allow(black_double).to receive(:getOptions).and_return({ 'maxelem' => '400', 'family' => 'inet', 'hashsize' => '2048' })
  end

  describe 'self.instances' do
    describe 'returns an array of ip sets' do
      it 'with correct names' do
        ipsets_names = provider.class.instances.map(&:name)
        expect(ipsets_names).to include('black', 'white')
      end

      it 'with correct families' do
        ipsets_families = provider.class.instances.map(&:family)
        expect(ipsets_families).to include('inet', 'inet6')
      end

      it 'with correct hashsizes' do
        ipsets_hashsize = provider.class.instances.map(&:hashsize)
        expect(ipsets_hashsize).to include('2048')
      end

      it 'with correct maxelems' do
        ipsets_maxelem = provider.class.instances.map(&:maxelem)
        expect(ipsets_maxelem).to include('200', '400')
      end
    end
  end

  describe 'when creating' do
    context 'basic ipset' do
      it 'creates a new ipset with entries' do
        expect(resource).to receive(:[]).with(:name).and_return('white').at_least(:once)
        expect(resource).to receive(:[]).with(:type).and_return('hash:net').at_least(:once)
        expect(resource).to receive(:[]).with(:family).and_return('inet').at_least(:once)
        expect(resource).to receive(:[]).with(:hashsize).and_return(1024).at_least(:once)
        expect(resource).to receive(:[]).with(:maxelem).and_return(65_536).at_least(:once)
        expect(resource).to receive(:[]).with(:timeout).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:options).and_return({}).at_least(:once)
        expect(resource).to receive(:[]).with(:manage_entries).and_return(true).at_least(:once)
        expect(resource).to receive(:[]).with(:entries).and_return(['192.168.0/24', '10.0.0/8'])

        expect(@config_interface_double).to receive(:addIPSet).with("white", "", "white", "", "hash:net", {"family"=>"inet", "hashsize"=>"1024", "maxelem"=>"65536"}, ["192.168.0/24", "10.0.0/8"])
        provider.create
      end
    end
  end

  describe 'when modifying' do
    context 'hashsize' do
      it 'removes and create a new ipset' do
        expect(resource).to receive(:[]).with(:name).and_return('white').at_least(:once)
        expect(resource).to receive(:[]).with(:type).and_return('hash:net').at_least(:once)
        expect(resource).to receive(:[]).with(:family).and_return('inet').at_least(:once)
        expect(resource).to receive(:[]).with(:hashsize).and_return(nil)
        expect(resource).to receive(:[]).with(:hashsize).and_return(2048)
        expect(resource).to receive(:[]).with(:maxelem).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:timeout).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:options).and_return({}).at_least(:once)
        expect(resource).to receive(:[]).with(:manage_entries).and_return(true).at_least(:once)
        expect(resource).to receive(:[]).with(:entries).and_return(['192.168.0/24', '10.0.0/8']).at_least(:once)

        expect(@config_interface_double).to receive(:addIPSet).with("white", "", "white", "", "hash:net", {"family"=>"inet"}, ["192.168.0/24", "10.0.0/8"])
        expect(@iface_double).to receive(:setOptions).with({ "family" => "inet", "hashsize" => "2048" })

        provider.create
        provider.hashsize = 2048
      end
    end

    context 'entries' do
      it 'removes and add entries' do
        expect(resource).to receive(:[]).with(:name).and_return('white').at_least(:once)
        expect(resource).to receive(:[]).with(:type).and_return('hash:net').at_least(:once)
        expect(resource).to receive(:[]).with(:family).and_return('inet').at_least(:once)
        expect(resource).to receive(:[]).with(:hashsize).and_return(nil)
        expect(resource).to receive(:[]).with(:maxelem).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:timeout).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:options).and_return({}).at_least(:once)
        expect(resource).to receive(:[]).with(:manage_entries).and_return(true).at_least(:once)
        expect(resource).to receive(:[]).with(:entries).and_return(['192.168.0.0/24', '10.0.0.0/8']).at_least(:once)

        expect(@config_interface_double).to receive(:addIPSet).with("white", "", "white", "", "hash:net", {"family"=>"inet"}, ["192.168.0.0/24", "10.0.0.0/8"])
        expect(@iface_double).to receive(:setEntries).with(['192.168.14.0/24', '10.0.0.0/8'])

        provider.create
        provider.entries = ['192.168.14.0/24', '10.0.0.0/8']
      end

      it 'ignores entries when manage_entries is false' do
        expect(resource).to receive(:[]).with(:name).and_return('white').at_least(:once)
        expect(resource).to receive(:[]).with(:type).and_return('hash:net').at_least(:once)
        expect(resource).to receive(:[]).with(:family).and_return('inet').at_least(:once)
        expect(resource).to receive(:[]).with(:hashsize).and_return(nil)
        expect(resource).to receive(:[]).with(:maxelem).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:timeout).and_return(nil).at_least(:once)
        expect(resource).to receive(:[]).with(:options).and_return({}).at_least(:once)
        expect(resource).to receive(:[]).with(:manage_entries).and_return(false).at_least(:once)

        expect(@config_interface_double).to receive(:addIPSet).with("white", "", "white", "", "hash:net", {"family"=>"inet"}, [])

        provider.create
        provider.entries = ['192.168.14.0/24', '10.0.0.0/8']
      end
    end
  end
end
