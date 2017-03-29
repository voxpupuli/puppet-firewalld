require 'spec_helper'

describe Puppet::Type.type(:firewalld_ipset) do

  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true)
  end

  describe "type" do
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
  end


  ## Provider tests for the firewalld_zone type
  #
  describe "provider" do

    let(:resource) {
      described_class.new(
        :name => 'whitelist', 
        :entries    => ['192.168.2.2', '10.72.1.100'])
    }
    let(:provider) {
      resource.provider
    }

    it "should check if it exists" do
      provider.expects(:execute_firewall_cmd).with(['--get-ipsets'], nil).returns("blacklist whitelist")
      expect(provider.exists?).to be_truthy
    end

    it "should check if it doesnt exist" do
      provider.expects(:execute_firewall_cmd).with(['--get-ipsets'], nil).returns("blacklist greenlist")
      expect(provider.exists?).to be_falsey
    end

    it "should create" do
      provider.expects(:execute_firewall_cmd).with(['--new-ipset=whitelist', '--type=hash:ip'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=192.168.2.2'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=10.72.1.100'], nil)
      provider.create
    end

    it "should remove" do
      provider.expects(:execute_firewall_cmd).with(['--delete-ipset=whitelist'], nil)
      provider.destroy
    end

    it "should set entries" do
      provider.expects(:entries).returns([])
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=192.168.2.2'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=10.72.1.100'], nil)
      provider.entries=(['192.168.2.2', '10.72.1.100'])
    end

    it "should remove unconfigured entries" do
      provider.expects(:entries).returns(['10.9.9.9', '10.8.8.8', '10.72.1.100'])
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--add-entry=192.168.2.2'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--remove-entry=10.9.9.9'], nil)
      provider.expects(:execute_firewall_cmd).with(['--ipset=whitelist', '--remove-entry=10.8.8.8'], nil)
      provider.entries=(['192.168.2.2', '10.72.1.100'])
    end

  end
end
