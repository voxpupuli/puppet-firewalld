require 'spec_helper'

describe Puppet::Type.type(:firewalld_custom_service) do
  before do
    # rubocop:disable RSpec/InstanceVariable
    @catalog = Puppet::Resource::Catalog.new
    described_class.any_instance.stubs(:catalog).returns(@catalog) # rubocop:disable RSpec/AnyInstance
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true) # rubocop:disable RSpec/AnyInstance
    # rubocop:enable RSpec/InstanceVariable
  end

  context ':name validation' do
    it 'has :name as its namevar' do
      expect(described_class.key_attributes).to eq([:name])
    end

    it 'accepts valid names' do
      resource = described_class.new(name: 'test_test')
      expect(resource[:name]).to eq('test_test')
    end
  end

  context ':short validation' do
    it 'accepts a valid short name' do
      short = 'Short Name'

      resource = described_class.new(
        name: 'test',
        short: short
      )

      expect(resource[:short]).to eq(short)
    end

    it 'rejects an invalid short name' do
      short = ''

      expect do
        described_class.new(
          name: 'test',
          short: short
        )
      end. to raise_error(%r{Valid values match})
    end
  end

  context ':description validation' do
    it 'accepts a valid description' do
      description = 'This is a description'

      resource = described_class.new(
        name: 'test',
        description: description
      )

      expect(resource[:description]).to eq(description)
    end

    it 'rejects an invalid description' do
      description = ''

      expect do
        described_class.new(
          name: 'test',
          description: description
        )
      end. to raise_error(%r{Valid values match})
    end
  end

  context ':ports validation' do
    valid_ports = [
      '1234-4567/tcp',
      '1234:4567/tcp',
      '1234/udp',
      '1234/sctp',
      '1234/dccp',
      '9169/tcp',
      '1/tcp',
      '65535/tcp',
      'tcp',
      { 'protocol' => 'tcp' },
      { 'port' => '1234:4567', 'protocol' => 'tcp' },
      { 'port' => 1234, 'protocol' => 'tcp' },
      { 'port' => 1234, 'protocol' => 'udp' },
      { 'port' => 1234, 'protocol' => 'sctp' },
      { 'port' => 1234, 'protocol' => 'dccp' },
      [
        '1234/tcp',
        { 'port' => 1234, 'protocol' => 'udp' },
        { 'port' => '1234', 'protocol' => 'sctp' },
        { 'port' => 1234, 'protocol' => 'dccp' }
      ]
    ]

    invalid_ports = [
      'bob/tcp',
      '/tcp',
      { 'port' => 1234 },
      [
        '1234/tcp',
        { 'port' => 1234, 'protocol' => 'udp' },
        { 'port' => '1234', 'protocol' => 'sctp' },
        { 'port' => 'bob', 'protocol' => 'dccp' }
      ]
    ]

    out_of_range_ports = [
      '0-100/tcp',
      '1-65536/tcp',
      '0/tcp',
      '96758/tcp'
    ]

    invalid_protocols = [
      '1234/bob',
      { 'port' => 1234, 'protocol' => 'bob' }
    ]

    valid_ports.each do |port|
      it "accepts port '#{port}'" do
        expect do
          described_class.new(
            name: 'test',
            ports: port
          )
        end.not_to raise_error
      end
    end

    invalid_ports.each do |port|
      it "rejects port '#{port}'" do
        expect do
          described_class.new(
            name: 'test',
            ports: port
          )
        end.to raise_error(%r{(Ports must match|must specify a protocol)})
      end
    end

    out_of_range_ports.each do |port|
      it "rejects port '#{port}'" do
        expect do
          described_class.new(
            name: 'test',
            ports: port
          )
        end.to raise_error(%r{Ports must be between})
      end
    end

    invalid_protocols.each do |protocol|
      it "rejects protocol'#{protocol}'" do
        expect do
          described_class.new(
            name: 'test',
            ports: protocol
          )
        end.to raise_error(%r{protocol must be one of})
      end
    end
  end

  context ':protocols validation' do
    it 'accepts valid protocols' do
      protocols = ['thing', 'other-thing', 'stuff', '@@bob']

      resource = described_class.new(
        name: 'test',
        protocols: protocols
      )

      expect(resource[:protocols]).to eq(protocols)
    end

    context 'invalid protocols' do
      protocols = [
        '',
        '#foo',
        'foo bar'
      ]

      protocols.each do |protocol|
        it "rejects #{protocol}" do
          expect do
            described_class.new(
              name: 'test',
              protocols: protocol
            )
          end. to raise_error(%r{Valid values match})
        end
      end
    end
  end

  context ':modules validation' do
    it 'accepts valid modules' do
      modules = ['nf_conntrack_ftp', 'thing', 'other_thing', 'new-thing']
      expected_modules = ['ftp', 'thing', 'other_thing', 'new-thing']

      resource = described_class.new(
        name: 'test',
        modules: modules
      )

      expect(resource[:modules]).to eq(expected_modules)
    end

    context 'invalid modules' do
      modules = [
        '',
        '#foo',
        'foo bar'
      ]

      modules.each do |mod|
        it "rejects #{mod}" do
          expect do
            described_class.new(
              name: 'test',
              modules: mod
            )
          end. to raise_error(%r{Valid values match})
        end
      end
    end
  end

  context ':ipv4_destination validation' do
    context 'valid destinations' do
      valid_destinations = [
        '1.2.3.4/5',
        '2.3.4.5'
      ]

      valid_destinations.each do |destination|
        it "accepts #{destination}" do
          resource = described_class.new(
            name: 'test',
            ipv4_destination: destination
          )

          expect(resource[:ipv4_destination]).to eq(destination)
        end
      end
    end

    context 'invalid destinations' do
      invalid_destinations = [
        '',
        '1.2.3.4/bob',
        '::1/alice',
        'stuff/24',
        '::1/128'
      ]

      invalid_destinations.each do |destination|
        it "rejects #{destination}" do
          expect do
            described_class.new(
              name: 'test',
              ipv4_destination: destination
            )
          end. to raise_error(%r{(invalid address|not an IPv4)})
        end
      end
    end
  end

  context ':ipv6_destination validation' do
    context 'valid destinations' do
      valid_destinations = [
        '::1/128',
        '::1'
      ]

      valid_destinations.each do |destination|
        it "accepts #{destination}" do
          resource = described_class.new(
            name: 'test',
            ipv6_destination: destination
          )

          expect(resource[:ipv6_destination]).to eq(destination)
        end
      end
    end

    context 'invalid destinations' do
      invalid_destinations = [
        '',
        '1.2.3.4/bob',
        '::1/alice',
        'stuff/24',
        '1.2.3.4/5',
        '2.3.4.5'
      ]

      invalid_destinations.each do |destination|
        it "rejects #{destination}" do
          expect do
            described_class.new(
              name: 'test',
              ipv6_destination: destination
            )
          end. to raise_error(%r{(invalid address|not an IPv6)})
        end
      end
    end
  end

  context 'autorequires' do
    # rubocop:disable RSpec/InstanceVariable
    before do
      firewalld_service = Puppet::Type.type(:service).new(name: 'firewalld')
      @catalog.add_resource(firewalld_service)
    end

    it 'autorequires the firewalld service' do
      resource = described_class.new(name: 'test')
      @catalog.add_resource(resource)

      expect(resource.autorequire.map { |rp| rp.source.to_s }).to include('Service[firewalld]')
    end
    # rubocop:enable RSpec/InstanceVariable
  end
end
