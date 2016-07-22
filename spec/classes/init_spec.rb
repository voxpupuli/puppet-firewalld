require 'spec_helper'

describe 'firewalld' do
  context 'with defaults for all parameters' do
    it { should contain_class('firewalld') }
  end

  context 'with parameter ports' do
    let(:params) do
      {
        ports:
          {
            'my_port' =>
              {
                'ensure'   => 'present',
                'port'     => '9999',
                'zone'     => 'public',
                'protocol' => 'tcp'
              }

          }
      }
    end

    it do
      should contain_firewalld_port('my_port')
        .with_ensure('present')
        .with_port('9999')
        .with_protocol('tcp')
        .with_zone('public')
        .that_notifies('Exec[firewalld::reload]')
        .that_requires('Service[firewalld]')
    end
  end

  context 'with parameter zones' do
    let(:params) do
      {
        zones:
        {
          'restricted' =>
                      {
                        'ensure' => 'present',
                        'target' => '%%REJECT%%'
                      }
        }
      }
    end

    it do
      should contain_firewalld_zone('restricted')
        .with_ensure('present')
        .with_target('%%REJECT%%')
        .that_notifies('Exec[firewalld::reload]')
        .that_requires('Service[firewalld]')
    end
  end

  context 'with parameter services' do
    let(:params) do
      {
        services:
        {
          'mysql' =>
            {
              'ensure' => 'present',
              'zone'   => 'public'
            }
        }
      }
    end

    it do
      should contain_firewalld_service('mysql')
        .with_ensure('present')
        .with_zone('public')
        .that_notifies('Exec[firewalld::reload]')
        .that_requires('Service[firewalld]')
    end
  end

  context 'with parameter rich_rules' do
    let(:params) do
      {
        rich_rules:
        {
          'Accept SSH from Gondor' =>
            {
              'ensure' => 'present',
              'zone'   => 'restricted',
              'source'  => '192.162.1.0/22',
              'service' => 'ssh',
              'action'  => 'accept'
            }
        }
      }
    end

    it do
      should contain_firewalld_rich_rule('Accept SSH from Gondor')
        .with_ensure('present')
        .with_zone('restricted')
        .that_notifies('Exec[firewalld::reload]')
        .that_requires('Service[firewalld]')
    end
  end

  context 'with parameter custom_service' do
    let(:params) do
      {
        'custom_services' =>
        {
          'MyService' =>
            {
              'ensure' => 'present',
              'short' => 'MyService',
              'description' => 'My Custom service',
              'port' => [
                { 'port' => '1234', 'protocol' => 'tcp' },
                { 'port' => '1234', 'protocol' => 'udp' }
              ]
            }
        }
      }
    end

    it do
      should contain_firewalld__custom_service('MyService')
        .with_ensure('present')
        .with_short('MyService')
        .with_port([{ 'port' => '1234', 'protocol' => 'tcp' }, { 'port' => '1234', 'protocol' => 'udp' }])
    end
  end

end
