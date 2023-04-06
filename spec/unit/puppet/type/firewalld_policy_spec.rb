require 'spec_helper'

describe Puppet::Type.type(:firewalld_policy) do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true) # rubocop:disable RSpec/AnyInstance
  end

  describe 'type' do
    context 'with no params' do
      describe 'when validating attributes' do
        [:name, :policy, :description, :short].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end

        [:target, :ingress_zones, :egress_zones,
         :priority, :masquerade, :icmp_blocks,
         :purge_rich_rules, :purge_services, :purge_ports].each do |prop|
          it "should have a #{prop} property" do
            expect(described_class.attrtype(prop)).to eq(:property)
          end
        end
      end
    end

    context 'validation' do
      it "should reject empty ingress_zones" do
        expect do
          described_class.new(name: "empty iz",
                              ingress_zones: [],
                              egress_zones: ["restricted"])
        end. to raise_error(
                  %r{parameter ingress_zones must contain at least one zone})
      end

      it "should reject empty egress_zones" do
        expect do
          described_class.new(name: "empty ez",
                              ingress_zones: ["public"],
                              egress_zones: [])
        end. to raise_error(
                  %r{parameter egress_zones must contain at least one zone})
      end

      it "should reject unset ingress_zones when ensure is not absent" do
        expect do
          described_class.new(name: "unset iz",
                              egress_zones: ["restricted"])
        end. to raise_error(
                  %r{parameter ingress_zones must be an array of strings})
      end

      it "should reject unset egress_zones when ensure is not absent" do
        expect do
          described_class.new(name: "unset ez",
                              ingress_zones: ["public"])
        end. to raise_error(
                  %r{parameter egress_zones must be an array of strings})
      end

      it "should not complain about unset iz/ez when ensure is absent" do
        nozones = described_class.new(name: 'unset iz/ez',
                                      ensure: :absent)
        expect(nozones[:ingress_zones]).to eq([])
        expect(nozones[:egress_zones]).to eq([])
      end

      it "should reject bad ingress_zones combinations" do
        expect do
          ["ANY", "HOST"].each do |symbolic_zone|
            described_class.new(name: "bad ingress_zones",
                                ingress_zones: [symbolic_zone, "public"],
                                egress_zones: ["restricted"])
          end. to raise_error(%r{parameter ingress_zones must contain a single symbolic zone or one or more regular zones})
        end
      end

      it "should reject bad egress_zones combinations" do
        expect do
          ["ANY", "HOST"].each do |symbolic_zone|
            described_class.new(name: "bad egress_zones",
                                ingress_zones: ["public"],
                                egress_zones: [symbolic_zone, "restricted"])
          end. to raise_error(%r{parameter egress_zones must contain a single symbolic zone or one or more regular zones})
        end
      end

      it "should accept lone symbolic ingress_zones" do
        ["ANY", "HOST"].each do |symbolic_zone|
          izresource = described_class.new(name: "symbolic iz",
                                           ingress_zones: [symbolic_zone],
                                           egress_zones: ["restricted"])
          expect(izresource[:ingress_zones]).to eq([symbolic_zone])
        end
      end

      it "should accept lone symbolic egress_zones" do
        ["ANY", "HOST"].each do |symbolic_zone|
          izresource = described_class.new(name: "symbolic iz",
                                           ingress_zones: ["public"],
                                           egress_zones: [symbolic_zone])
          expect(izresource[:egress_zones]).to eq([symbolic_zone])
        end
      end

      it "should munge priority to string" do
        [-17, -1, 1, 17].each do |prio|
          presource = described_class.new(name: "prio as numeric",
                                          ingress_zones: ["public"],
                                          egress_zones: ["restricted"],
                                          priority: prio)
          expect(presource[:priority]).to eq(prio.to_s)
        end
      end
    end
  end

  ## Provider tests for the firewalld_policy type
  #
  describe 'provider' do
    context 'with standard parameters' do
      let(:resource) do
        described_class.new(
          name: 'public2restricted',
          target: '%%REJECT%%',
          ingress_zones: ['public'],
          egress_zones: ['restricted'],
          icmp_blocks: ['redirect', 'router-advertisment']
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'should check if it exists' do
        provider.expects(:execute_firewall_cmd_policy).with(['--get-policies'], nil).returns('public2restricted other')
        expect(provider).to be_exists
      end

      it 'should check if it doesnt exist' do
        provider.expects(:execute_firewall_cmd_policy).with(['--get-policies'], nil).returns('wrong other')
        expect(provider).not_to be_exists
      end

      it 'should evalulate target' do
        provider.expects(:execute_firewall_cmd_policy).with(['--get-target']).returns('%%REJECT%%')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'should evalulate target correctly when not surrounded with %%' do
        provider.expects(:execute_firewall_cmd_policy).with(['--get-target']).returns('REJECT')
        expect(provider.target).to eq('%%REJECT%%')
      end

      it 'should add policy when created' do
        provider.expects(:execute_firewall_cmd_policy).with(['--new-policy', 'public2restricted'], nil)
        provider.expects(:execute_firewall_cmd_policy).with(['--set-target', '%%REJECT%%'])
        provider.expects(:execute_firewall_cmd_policy).with(['--set-priority', '-1'])

        provider.expects(:icmp_blocks=).with(['redirect', 'router-advertisment'])

        provider.expects(:ingress_zones).returns([])
        provider.expects(:execute_firewall_cmd_policy).with(['--add-ingress-zone', 'public'])

        provider.expects(:egress_zones).returns([])
        provider.expects(:execute_firewall_cmd_policy).with(['--add-egress-zone', 'restricted'])
        provider.create
      end

      it 'should delete policy when destroyed' do
        provider.expects(:execute_firewall_cmd_policy).with(['--delete-policy', 'public2restricted'], nil)
        provider.destroy
      end

      it 'should set target' do
        provider.expects(:execute_firewall_cmd_policy).with(['--set-target', '%%REJECT%%'])
        provider.target = '%%REJECT%%'
      end

      it 'should get ingress zones' do
        provider.expects(:execute_firewall_cmd_policy).with(['--list-ingress-zones']).returns('public')
        expect(provider.ingress_zones).to eq(['public'])
      end

      it 'should get egress zones' do
        provider.expects(:execute_firewall_cmd_policy).with(['--list-egress-zones']).returns('restricted')
        expect(provider.egress_zones).to eq(['restricted'])
      end

      it 'should get icmp_blocks' do
        provider.expects(:execute_firewall_cmd_policy).with(['--list-icmp-blocks']).returns('val')
        expect(provider.icmp_blocks).to eq(['val'])
      end

      it 'should list icmp types' do
        provider.expects(:execute_firewall_cmd_policy).with(['--get-icmptypes'], nil).returns('echo-reply echo-request')
        expect(provider.get_icmp_types).to eq(['echo-reply', 'echo-request'])
      end
    end

    context 'when specifiying masquerade' do
      let(:resource) do
        described_class.new(
          name: 'public2restricted',
          ensure: :present,
          masquerade: true,
          ingress_zones: ['public'],
          egress_zones: ['restricted']
        )
      end
      let(:provider) do
        resource.provider
      end

      it 'should set masquerading' do
        provider.expects(:execute_firewall_cmd_policy).with(['--add-masquerade'])
        provider.masquerade = :true
      end

      it 'should disable masquerading' do
        provider.expects(:execute_firewall_cmd_policy).with(['--remove-masquerade'])
        provider.masquerade = :false
      end

      it 'should get masquerading state as false when not set' do
        provider.expects(:execute_firewall_cmd_policy).with(['--query-masquerade'], 'public2restricted', true, false).returns("no\n")
        expect(provider.masquerade).to eq(:false)
      end
      it 'should get masquerading state as true when set' do
        provider.expects(:execute_firewall_cmd_policy).with(['--query-masquerade'], 'public2restricted', true, false).returns("yes\n")
        expect(provider.masquerade).to eq(:true)
      end
    end
  end

  context 'autorequires' do
    # rubocop:disable RSpec/InstanceVariable
    before do
      firewalld_service = Puppet::Type.type(:service).new(name: 'firewalld')
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(firewalld_service)
    end

    it 'should autorequire the firewalld service' do
      resource = described_class.new(
        name: 'public2restricted',
        ingress_zones: ["public"],
        egress_zones: ["restricted"]
      )
      @catalog.add_resource(resource)

      expect(resource.autorequire.map { |rp| rp.source.to_s }).to include('Service[firewalld]')
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
