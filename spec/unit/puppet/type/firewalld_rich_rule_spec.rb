require 'spec_helper'

describe Puppet::Type.type(:firewalld_rich_rule) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true)
  end
  context 'with no params' do
    describe 'when validating attributes' do
      [
         :family,
         :zone,
         :source,
         :service,
         :action,
         :protocol,
         :icmp_block,
         :masquerade,
         :forward_port,
         :log,
         :audit,
         :action,
         :raw_rule,
      ].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end
  end

  describe 'action validation' do
    it 'raises an error if wrong action string' do
      expect do described_class.new(
        title: 'SSH from barny',
        action: 'accepted',
      ) end.to raise_error(/Authorized action values are `accept`, `reject`, `drop` or `mark`/)
    end
    it 'raises an error if wrong action hash keys' do
      expect do described_class.new(
        title: 'SSH from barny',
        action: {type: 'accepted', foo: 'bar'},
      ) end.to raise_error(/Rule action hash should contain `action` and `type` keys. Use a string if you only want to declare the action to be `accept` or `reject`/)
    end
    it 'raises an error if wrong action hash values' do
      expect do described_class.new(
        title: 'SSH from barny',
        action: {type: 'icmp-admin-prohibited', action: 'accepted'},
      ) end.to raise_error(/Authorized action values are `accept`, `reject`, `drop` or `mark`/)
    end

  end

  describe 'namevar validation' do
    let(:attrs) {{
      title: 'SSH from barny',
      ensure: 'present',
      zone: 'restricted',
      source: '192.168.1.2/32',
      dest: '192.168.99.2/32',
      service: 'ssh',
      action: 'accept'
    }}

    it 'has :name as its namevar' do
      expect(described_class.key_attributes).to eq([:name])
    end

    it 'defaults family to ipv4' do
      resource=described_class.new(attrs)
      expect(resource[:family]).to eq('ipv4')
    end

    it 'raises an error if given malformed inet protocol' do
      expect { described_class.new(attrs.merge({family: 'bad'})) }.to raise_error(Puppet::Error)
    end

    it 'converts source into a hash' do
      expect(described_class.new(attrs)[:source]).to be_a(Hash)
    end

    it 'converts dest into a hash' do
      expect(described_class.new(attrs)[:dest]).to be_a(Hash)
    end

  end

  ## Many more scenarios needed!
  #
  describe 'provider' do

    scenarios = {
      ## Test source
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        source: { 'address' => '10.0.1.2/24' },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept',
      } => 'rule family="ipv4" source address="10.0.1.2/24" service name="ssh" log level="debug" accept',
      ## Test ipset
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        source: { 'ipset' => 'whitelist' },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept',
      } => 'rule family="ipv4" source ipset="whitelist" service name="ssh" log level="debug" accept',

      ## Test destination
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        dest: '10.0.1.2/24',
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept',
      } => 'rule family="ipv4" destination address="10.0.1.2/24" service name="ssh" log level="debug" accept',

      ## Test address invertion
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        source: { 'address' => '10.0.1.2/24', 'invert' => true },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept',
      } => 'rule family="ipv4" source NOT address="10.0.1.2/24" service name="ssh" log level="debug" accept',
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        dest: { 'address' => '10.0.1.2/24', 'invert' => true },
        service: 'ssh',
        log: { 'level' => 'debug' },
        action: 'accept',
      } => 'rule family="ipv4" destination NOT address="10.0.1.2/24" service name="ssh" log level="debug" accept',

      ## test port
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        zone: 'restricted',
        dest: '10.0.1.2/24',
        port: { 'port' => '22', 'protocol' => 'tcp' },
        log: { 'level' => 'debug' },
        action: 'accept',
      } => 'rule family="ipv4" destination address="10.0.1.2/24" port port="22" protocol="tcp" log level="debug" accept',

      ## test forward port
      {
        name: 'accept ssh',
        ensure: 'present',
        family: 'ipv4',
        forward_port: { 'port' => '8080', 'protocol' => 'tcp', 'to_addr' => '10.72.1.10', 'to_port' => '80' },
        zone: 'restricted',
        log: { 'level' => 'debug' },
      } => 'rule family="ipv4" forward-port port="8080" protocol="tcp" to-port="80" to-addr="10.72.1.10" log level="debug"',

    }

    scenarios.each do |attrs, rawrule|

      context "for rule #{rawrule}" do

        let(:resource) {
          described_class.new(attrs)
        }
        before do
          @fakeclass = Class.new
        end
        let(:provider) { resource.provider }
        let(:rawrule) {
          'rule family="ipv4" source address="10.0.1.2/24" service name="ssh" log level="debug" accept'
        }

        it 'queries the status' do
          @fakeclass.stubs(:exitstatus).returns(0)
          provider.expects(:execute_firewall_cmd).with(['--query-rich-rule', rawrule], 'restricted', true, false).returns(@fakeclass)
          expect(provider.exists?).to be_truthy
        end

        it 'creates' do
          provider.expects(:execute_firewall_cmd).with(['--add-rich-rule', rawrule])
          provider.create
        end

        it 'destroys' do
          provider.expects(:execute_firewall_cmd).with(['--remove-rich-rule', rawrule])
          provider.destroy
        end
      end
    end
  end
end
