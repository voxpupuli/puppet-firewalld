# frozen_string_literal: true

require 'spec_helper'

provider_class = Puppet::Type.type(:firewalld_ipset).provider(:firewall_cmd)

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
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--get-ipsets'], nil).and_return('white black')
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--state'], nil, false, false, false).and_return(double(exitstatus: 0))
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--info-ipset=white'], nil).and_return(<<~DATA.chomp)
      white
        type: hash:ip
        options: maxelem=200 family=inet6
        entries:
    DATA
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--info-ipset=black'], nil).and_return(<<~DATA.chomp)
      black
        type: hash:ip
        options: maxelem=400 family=inet hashsize=2048
        entries:
    DATA
    allow(provider_class).to receive(:execute_firewall_cmd).with(['--ipset=white', '--get-entries'], nil).and_return('')
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
        expect(resource).to receive(:[]).with(:manage_entries).and_return(true)
        expect(resource).to receive(:[]).with(:entries).and_return(['192.168.0/24', '10.0.0/8'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet', '--option=hashsize=1024', '--option=maxelem=65536'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--add-entry=192.168.0/24'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--add-entry=10.0.0/8'], nil)
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet', '--option=hashsize=2048'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--add-entry=192.168.0/24'], nil).at_least(:once)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--add-entry=10.0.0/8'], nil).at_least(:once)
        expect(provider).to receive(:execute_firewall_cmd).with(['--delete-ipset=white'], nil)
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
        expect(provider).to receive(:entries).and_return(['192.168.0.0/24', '10.0.0.0/8'])
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--add-entry=192.168.0.0/24'], nil).at_least(:once)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--add-entry=10.0.0.0/8'], nil).at_least(:once)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--add-entry=192.168.14.0/24'], nil)
        expect(provider).to receive(:execute_firewall_cmd).with(['--ipset=white', '--remove-entry=192.168.0.0/24'], nil)
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
        expect(provider).to receive(:execute_firewall_cmd).with(['--new-ipset=white', '--type=hash:net', '--option=family=inet'], nil)
        provider.create
        provider.entries = ['192.168.14.0/24', '10.0.0.0/8']
      end
    end
  end
end
