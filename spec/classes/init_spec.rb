require 'spec_helper'
require 'puppet/provider/firewalld'

describe 'firewalld' do
  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:running).returns(:true) # rubocop:disable RSpec/AnyInstance
  end

  let(:facts) do
    {
      firewalld_version: '0.5.0'
    }
  end

  context 'with defaults for all parameters' do
    it { is_expected.to contain_class('firewalld') }

    it {
      is_expected.to contain_package('firewalld').
        with_ensure('installed').
        that_notifies('Service[firewalld]')
    }

    it {
      is_expected.to contain_service('firewalld').
        with_ensure('running').
        with_enable(true)
    }

    it { is_expected.not_to contain_augeas('firewalld::firewallbackend') }
  end

  context 'when defining a default zone' do
    let(:params) do
      {
        default_zone: 'restricted'
      }
    end

    it do
      is_expected.to contain_exec('firewalld::set_default_zone').with(
        command: 'firewall-cmd --set-default-zone restricted',
        unless: '[ $(firewall-cmd --get-default-zone) = restricted ]'
      ).that_requires('Service[firewalld]')
    end
  end

  context 'with purge options' do
    let(:params) do
      {
        purge_direct_rules: true,
        purge_direct_chains: true,
        purge_direct_passthroughs: true,
        purge_unknown_ipsets: true
      }
    end

    it do
      is_expected.to contain_firewalld_direct_purge('rule')
    end

    it do
      is_expected.to contain_firewalld_direct_purge('passthrough')
    end

    it do
      is_expected.to contain_firewalld_direct_purge('chain')
    end

    it do
      is_expected.to contain_resources('firewalld_ipset').
        with_purge(true)
    end
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
      is_expected.to contain_firewalld_port('my_port').
        with_ensure('present').
        with_port('9999').
        with_protocol('tcp').
        with_zone('public').
        that_notifies('Class[firewalld::reload]').
        that_requires('Service[firewalld]')
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
      is_expected.to contain_firewalld_zone('restricted').
        with_ensure('present').
        with_target('%%REJECT%%').
        that_requires('Service[firewalld]')
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
      is_expected.to contain_firewalld_service('mysql').
        with_ensure('present').
        with_zone('public').
        that_notifies('Class[firewalld::reload]').
        that_requires('Service[firewalld]')
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
      is_expected.to contain_firewalld_rich_rule('Accept SSH from Gondor').
        with_ensure('present').
        with_zone('restricted').
        that_notifies('Class[firewalld::reload]').
        that_requires('Service[firewalld]')
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
      is_expected.not_to contain_file('/etc/firewalld/services/MyService.xml')

      is_expected.to contain_firewalld__custom_service('MyService').
        with_ensure('present').
        with_short('MyService').
        with_port([{ 'port' => '1234', 'protocol' => 'tcp' }, { 'port' => '1234', 'protocol' => 'udp' }])
    end

    context 'with an invalid filename' do
      let(:params) do
        {
          'custom_services' =>
          {
            'MyService' =>
              {
                'ensure' => 'present',
                'short' => 'My Service',
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
        is_expected.to contain_file('/etc/firewalld/services/My Service.xml').with_ensure('absent')

        is_expected.to contain_firewalld__custom_service('MyService').
          with_short('My Service').
          with_ensure('present').
          with_port([{ 'port' => '1234', 'protocol' => 'tcp' }, { 'port' => '1234', 'protocol' => 'udp' }])
      end
    end
  end

  context 'with default_zone' do
    let(:params) do
      {
        default_zone: 'public'
      }
    end

    it do
      is_expected.to contain_exec('firewalld::set_default_zone').with(
        command: 'firewall-cmd --set-default-zone public',
        unless: '[ $(firewall-cmd --get-default-zone) = public ]'
      ).that_requires('Service[firewalld]')
    end
  end

  %w[unicast broadcast multicast all off].each do |cond|
    context "with log_denied set to #{cond}" do
      let(:params) do
        {
          log_denied: cond
        }
      end

      it do
        is_expected.to contain_exec('firewalld::set_log_denied').with(
          command: "firewall-cmd --set-log-denied #{cond}",
          unless: "[ \$\(firewall-cmd --get-log-denied) = #{cond} ]"
        ).that_requires('Service[firewalld]')
      end
    end
  end

  context 'with parameter cleanup_on_exit' do
    let(:params) do
      {
        cleanup_on_exit: 'yes'
      }
    end

    it do
      is_expected.to contain_augeas('firewalld::cleanup_on_exit').with(
        changes: ['set CleanupOnExit "yes"']
      )
    end
  end

  context 'with parameter zone_drifting' do
    let(:params) do
      {
        zone_drifting: 'yes'
      }
    end

    it do
      is_expected.to contain_augeas('firewalld::zone_drifting').with(
        changes: ['set AllowZoneDrifting "yes"']
      )
    end
  end

  context 'with parameter minimal_mark' do
    let(:params) do
      {
        minimal_mark: 10
      }
    end

    it do
      is_expected.to contain_augeas('firewalld::minimal_mark').with(
        changes: ['set MinimalMark "10"']
      )
    end
  end

  context 'with parameter lockdown' do
    let(:params) do
      {
        lockdown: 'yes'
      }
    end

    it do
      is_expected.to contain_augeas('firewalld::lockdown').with(
        changes: ['set Lockdown "yes"']
      )
    end
  end

  context 'with parameter firewall_backend' do
    context 'with firewalld version' do
      let(:params) do
        {
          firewall_backend: 'nftables'
        }
      end

      ['0.6.0', '1.0.0'].each do |version|
        let(:facts) do
          {
            firewalld_version: version
          }
        end

        context version do
          it do
            is_expected.to contain_augeas('firewalld::firewall_backend').with(
              changes: ['set FirewallBackend "nftables"']
            )
          end
        end
      end

      context '0.5.0' do
        let(:facts) do
          {
            firewalld_version: '0.5.0'
          }
        end

        it do
          is_expected.not_to contain_augeas('firewalld::firewall_backend')
        end
      end
    end
  end

  context 'with parameter ipv6_rpfilter' do
    let(:params) do
      {
        ipv6_rpfilter: 'yes'
      }
    end

    it do
      is_expected.to contain_augeas('firewalld::ipv6_rpfilter').with(
        changes: ['set IPv6_rpfilter "yes"']
      )
    end
  end
end
