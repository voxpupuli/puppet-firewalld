require 'spec_helper'

describe Puppet::Type.type(:firewalld_ipset) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true) # rubocop:disable RSpec/AnyInstance
  end

  describe 'type' do
    describe 'when validating attributes' do
      [:name, :type, :options, :manage_entries].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end

      [:entries, :family, :hashsize, :maxelem, :timeout].each do |prop|
        it "should have a #{prop} property" do
          expect(described_class.attrtype(prop)).to eq(:property)
        end
      end
    end
    describe 'when validating attribute values' do
      describe 'hashsize' do
        [128, 256, 512, 1024, '1024'].each do |value|
          it "should support #{value} as a value to hashsize" do
            expect { described_class.new(name: 'test', hashsize: value) }.not_to raise_error
          end
        end
        ['foo', '3.5'].each do |value|
          it "should not support #{value} as a value to hashsize" do
            expect { described_class.new(name: 'test', hashsize: value) }.to raise_error(Puppet::Error, %r{hashsize must be an integer})
          end
        end
        [0, '0', -1, '-1'].each do |value|
          it "should not support #{value} as a value to hashsize" do
            expect { described_class.new(name: 'test', hashsize: value) }.to raise_error(Puppet::Error, %r{hashsize must be a positive integer})
          end
        end
        [5, 41, '99'].each do |value|
          it "should not support #{value} as a value to hashsize" do
            expect { described_class.new(name: 'test', hashsize: value) }.to raise_error(Puppet::Error, %r{hashsize must be a power of 2})
          end
        end
      end
      describe 'maxelem' do
        [2048, '3000', 65_536].each do |value|
          it "should support #{value} as a value to maxelem" do
            expect { described_class.new(name: 'test', maxelem: value) }.not_to raise_error
          end
        end
        [0, 'foo', '3.5', -1, 0.6, '-1000.3'].each do |value|
          it "should not support #{value} as a value to maxelem" do
            expect { described_class.new(name: 'test', maxelem: value) }.to raise_error(Puppet::Error, %r{Invalid value})
          end
        end
      end
      describe 'timeout' do
        [0, '0', 60, 3600, '2147483'].each do |value|
          it "should support #{value} as a value to timeout" do
            expect { described_class.new(name: 'test', timeout: value) }.not_to raise_error
          end
        end
        ['foo', '3.5', -1, 0.6, '-1000.3'].each do |value|
          it "should not support #{value} as a value to timeout" do
            expect { described_class.new(name: 'test', timeout: value) }.to raise_error(Puppet::Error, %r{Invalid value})
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
      end.to raise_error(%r{IPset name must be a word with no spaces})
    end
    it 'accept - in name' do
      expect do
        described_class.new(
          name: 'white-blue',
          type: 'hash:net'
        )
      end.not_to raise_error
    end
    it 'accept . in name' do
      expect do
        described_class.new(
          name: 'white.blue',
          type: 'hash:net'
        )
      end.not_to raise_error
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
      end.to raise_error(%r{Ipset should not declare entries if it doesn't manage entries})
    end
  end

  context 'autorequires' do
    # rubocop:disable RSpec/InstanceVariable
    before do
      firewalld_service = Puppet::Type.type(:service).new(name: 'firewalld')
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(firewalld_service)
    end

    it 'autorequires the firewalld service' do
      resource = described_class.new(name: 'test', hashsize: 128)
      @catalog.add_resource(resource)

      expect(resource.autorequire.map { |rp| rp.source.to_s }).to include('Service[firewalld]')
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
