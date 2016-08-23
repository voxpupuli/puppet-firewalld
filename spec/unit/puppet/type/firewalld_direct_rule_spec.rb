require 'spec_helper'

describe Puppet::Type.type(:firewalld_direct_rule) do
  context 'with no params' do
    describe 'when validating attributes' do
      [:inet_protocol, :args, :table, :chain, :priority].each do |param|
        it "should have a #{param} parameter" do
          expect(described_class.attrtype(param)).to eq(:param)
        end
      end
    end

    describe 'namevar validation' do
      let(:attrs) {{
        :title  => 'Allow SSH',
        :ensure => 'present',
        :table => 'filter',
        :chain => 'OUTPUT',
        :priority => 1,
        :args => '-p tcp ---dport=22 -j ACCEPT'
      }}

      it 'should have :name as its namevar' do
        expect(described_class.key_attributes).to eq([:name])
      end


      it 'should default inet_protocol to ipv4' do
        resource=described_class.new(attrs)
        expect(resource[:inet_protocol]).to eq("ipv4")
      end

      it 'should raise an error if given malformed inet protocol' do
        expect { described_class.new(attrs.merge({:inet_protocol => 'bad'})) }.to raise_error(Puppet::Error)
      end

    end
  end

  describe "provider" do
    let(:resource) {
      described_class.new(
          :name           => 'allow ssh',
          :ensure         => 'present',
          :inet_protocol  => 'ipv4',
          :table          => 'filter',
          :chain          => 'OUTPUT',
          :priority       => 4,
          :args           => '-p tcp --dport=22 -j ACCEPT',
      )
    }

    let(:provider) { resource.provider }

    it "should create" do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--add-rule', [ 'ipv4', 'filter', 'OUTPUT', '4', '-p', 'tcp', '--dport=22', '-j', 'ACCEPT']], nil)
      provider.create
    end

    it "should destroy" do
      provider.expects(:execute_firewall_cmd).with(['--direct', '--remove-rule', [  'ipv4', 'filter', 'OUTPUT', '4', '-p', 'tcp', '--dport=22', '-j', 'ACCEPT']], nil)
      provider.destroy
    end

    context "parsing arguments" do
      it "should correctly parse arguments into an array" do
        args="-p tcp --dport=22 -j ACCEPT"
        expect(provider.parse_args(args)).to eq(['-p', 'tcp', '--dport=22', '-j', 'ACCEPT'])
      end

      it "should correctly parse arguments in quotes" do
        args="-j LOG --log-prefix '# IPTABLES DROPPED:'"
        expect(provider.parse_args(args)).to eq(['-j', 'LOG', '--log-prefix', '\'# IPTABLES DROPPED:\''])
      end
    end


  end
end
