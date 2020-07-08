require 'spec_helper'

describe 'firewalld::custom_service' do
  let(:title) { 'My Service' }

  context 'when defining with specific ports' do
    let(:params) do
      {
        short: 'myservice',
        description: 'My multi port service',
        port: [
          {
            'port'     => '8000',
            'protocol' => 'tcp'
          },
          {
            'port'     => '8000',
            'protocol' => 'udp'
          },
          {
            'port'     => '8001',
            'protocol' => 'tcp'
          },
          {
            'port'     => '8001',
            'protocol' => 'udp'
          },
          {
            'port'     => '8002',
            'protocol' => 'tcp'
          },
          {
            'port'     => '8002',
            'protocol' => 'udp'
          },
          {
            'port'     => '',
            'protocol' => 'vrrp'
          }
        ],
        module: ['nf_conntrack_netbios_ns'],
        destination: {
          'ipv4' => '127.0.0.1',
          'ipv6' => '::1'
        }
      }
    end

    it do
      is_expected.to contain_firewalld_custom_service('myservice').with(
        short: params[:short],
        description: params[:description],
        ports: params[:port],
        modules: params[:module],
        ipv4_destination: params[:destination]['ipv4'],
        ipv6_destination: params[:destination]['ipv6']
      )
    end
  end

  context 'when defining with integer ports' do
    let(:params) do
      {
        short: 'my service',
        filename: 'myservice_file',
        description: 'My multi port service',
        port: [
          {
            'port'     => 8000,
            'protocol' => 'tcp'
          },
          {
            'port'     => 8000,
            'protocol' => 'udp'
          },
          {
            'port'     => 8001,
            'protocol' => 'tcp'
          },
          {
            'port'     => 8001,
            'protocol' => 'udp'
          },
          {
            'port'     => 8002,
            'protocol' => 'tcp'
          },
          {
            'port'     => 8002,
            'protocol' => 'udp'
          },
          {
            'port'     => '',
            'protocol' => 'vrrp'
          }

        ],
        module: ['nf_conntrack_netbios_ns'],
        destination: {
          'ipv4' => '127.0.0.1',
          'ipv6' => '::1'
        }
      }
    end

    it do
      is_expected.to contain_firewalld_custom_service('myservice_file').with(
        short: params[:short],
        description: params[:description],
        ports: params[:port],
        modules: params[:module],
        ipv4_destination: params[:destination]['ipv4'],
        ipv6_destination: params[:destination]['ipv6']
      )
    end
  end

  context 'when defining with a port range' do
    let(:params) do
      {
        short: 'myservice',
        description: 'My multi port service',
        port: [
          {
            'port'     => '8000:8002',
            'protocol' => 'tcp'
          },
          {
            'port'     => '8000:8002',
            'protocol' => 'udp'
          }
        ]
      }
    end

    it do
      is_expected.to contain_firewalld_custom_service('myservice').with(
        short: params[:short],
        description: params[:description],
        ports: params[:port]
      )
    end
  end
end
