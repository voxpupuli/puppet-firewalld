require 'spec_helper'

describe Puppet::Type.type(:firewalld_ipset) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true)
  end

  describe 'type' do
    context 'with no params' do
      describe 'when validating attributes' do
        [
          :name, :type, :options
        ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end

        [
          :entries
        ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:property)
          end
        end
      end
    end
    it 'raises an error if wrong name' do
      expect do
        described_class.new(
        name: 'white black',
        type: 'hash:net'
        )
      end.to raise_error(/IPset name must be a word with no spaces/)
    end
    it 'accept - in name' do
      expect do
        described_class.new(
        name: 'white-blue',
        type: 'hash:net'
        )
      end.to_not raise_error
    end
  end

  ## Provider tests for the firewalld_zone type
  #
  describe 'provider' do
    let(:resource) do
      described_class.new(
        name: 'whitelist',
        entries: ['192.168.2.2', '10.72.1.100']
      )
    end
    let(:provider) do
      resource.provider
    end

    it 'creates' do
      provider.expects(:execute_firewall_cmd).with(['--new-ipset=whitelist', '--type=hash:ip'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=192.168.2.2'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=10.72.1.100'], nil)
      provider.create
    end

    it 'removes' do
      provider.expects(:execute_firewall_cmd).with(['--delete-ipset=whitelist'], nil)
      provider.destroy
    end

    it 'sets entries' do
      provider.expects(:entries).returns([])
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=192.168.2.2'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=10.72.1.100'], nil)
      provider.entries = ['192.168.2.2', '10.72.1.100']
    end

    it 'removes unconfigured entries' do
      provider.expects(:entries).returns(['10.9.9.9', '10.8.8.8', '10.72.1.100'])
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=192.168.2.2'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--remove-entry=10.9.9.9'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--remove-entry=10.8.8.8'], nil)
      provider.entries = ['192.168.2.2', '10.72.1.100']
    end
  end
  context 'change in ipset members' do
    let(:resource) do
      Puppet::Type.type(:firewalld_ipset).new(
        name: 'white',
        type: 'hash:net',
        entries: ['8.8.8.8/32', '9.9.9.9']
      )
    end

    it 'removes /32 in set members' do
      expect(resource[:entries]).to eq ['8.8.8.8', '9.9.9.9']
    end
  end

  context 'validation when not managing ipset entries ' do
    it 'raises an error if wrong type' do
      expect do
        Puppet::Type.type(:firewalld_ipset).new(
        name: 'white',
        type: 'hash:net',
        manage_entries: false,
        entries: ['8.8.8.8/32', '9.9.9.9']
        )
      end.to raise_error(/Ipset should not declare entries if it doesn't manage entries/)
    end
  end
end
