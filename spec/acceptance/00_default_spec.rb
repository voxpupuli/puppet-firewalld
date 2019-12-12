require 'spec_helper_acceptance'

describe 'firewalld', unless: UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  # This is a VERY MINIMAL test
  #
  # Additional tests should be added to cover all module capabilities
  hosts.each do |host|
    context "on #{host}" do
      let(:manifest) do
        <<-EOM
          class { 'firewalld':
            lockdown     => 'yes',
            default_zone => 'test',
            log_denied   => 'unicast'
          }

          firewalld_zone { 'test':
            ensure           => 'present',
            purge_rich_rules => true,
            purge_services   => true,
            purge_ports      => true,
            target           => 'DROP',
            require          => Service['firewalld']
          }

          firewalld::custom_service { 'test_sshd':
            short       => 'test_sshd',
            description => 'Test SSH Access',
            port        => [{ 'port' => '22', 'protocol' => 'tcp' }],
            require     => Service['firewalld']
          }

          firewalld_service { 'test_sshd':
            zone    => 'test',
            require => Service['firewalld']
          }
        EOM
      end

      it 'runs successfully' do
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it 'is running firewalld' do
        svc = YAML.load(on(host, 'puppet resource service firewalld --to_yaml').output)
        expect(svc['service']['firewalld']['ensure']).to match('running')
      end

      it 'has "test" as the default zone' do
        default_zone = on(host, 'firewall-cmd --get-default-zone').output.strip
        expect(default_zone).to eq('test')
      end

      it 'has the "test_sshd" service in the "test" zone' do
        test_services = on(host, 'firewall-cmd --list-services --zone=test').output.strip.split(%r{\s+})
        expect(test_services).to include('test_sshd')
      end
    end
  end
end
