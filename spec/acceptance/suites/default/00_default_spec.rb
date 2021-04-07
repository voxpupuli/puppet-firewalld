require 'spec_helper_acceptance'

describe 'firewalld', unless: UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  # This is a VERY MINIMAL test
  #
  # Additional tests should be added to cover all module capabilities
  hosts.each do |host|
    context "on #{host}" do
      context 'custom services' do
        let(:manifest) do
          <<-EOM
            class { 'firewalld':
              lockdown     => 'yes',
              default_zone => 'test',
              log_denied   => 'unicast'
            }

            class ssh_test {
              firewalld_service{ 'test_sshd': zone => 'test' }

  # TODO: Switch this when the defined type gets deprecated
              firewalld::custom_service{ 'test_sshd':
                description => 'Test SSH Access',
                port        => [{ 'port' => '22', 'protocol' => 'tcp' }]
              }
            }

            firewalld_zone{ 'test':
              ensure           => 'present',
              purge_rich_rules => true,
              purge_services   => true,
              purge_ports      => true,
              target           => 'DROP'
            }

            class other_service {
              firewalld_service{ 'test_thing': zone => 'test' }

              #{test_thing_resource}
            }

            # Check for looping
            include ssh_test
            include other_service

            Class['ssh_test'] -> Class['other_service']
          EOM
        end

        context 'with a default test resource' do
          let(:test_thing_resource) do
            <<-EOM
              firewalld_custom_service{ 'test_thing':
                description      => 'Random service test',
                ports            => ['1234/tcp', { 'port' => '1234', 'protocol' => 'udp' }],
                protocols        => ['ip', 'smp'],
                modules          => ['nf_conntrack_tftp', 'nf_conntrack_snmp'],
                ipv4_destination => '1.2.3.4/23',
                ipv6_destination => '::1'
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
            svc = YAML.safe_load(on(host, 'puppet resource service firewalld --to_yaml').output)
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

          context 'custom service' do
            it 'exists' do
              expect(on(host, 'firewall-cmd --permanent --info-service=test_thing').output).not_to be_empty
            end

            it 'has the proper description' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-description').output.strip).to eq('Random service test')
            end

            it 'has no short description' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-short').output.strip).to be_empty
            end

            it 'has the proper ports' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-ports').output.strip).to eq('1234/tcp 1234/udp')
            end

            it 'has the proper protocols' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-protocols').output.strip).to eq('ip smp')
            end

            it 'has the proper modules' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-modules').output.strip).to eq('tftp snmp')
            end

            it 'has the proper destinations' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-destinations').output.strip).to eq('ipv4:1.2.3.4/23 ipv6:::1')
            end
          end
        end

        context 'with a modified test resource' do
          let(:test_thing_resource) do
            <<-EOM
              firewalld_custom_service{ 'test_thing':
                short => 'Short test',
                ports => ['1235/tcp', { 'port' => '1236', 'protocol' => 'tcp' }],
              }
            EOM
          end

          it 'runs successfully' do
            apply_manifest_on(host, manifest, catch_failures: true)
          end

          it 'is idempotent' do
            apply_manifest_on(host, manifest, catch_changes: true)
          end

          context 'custom service' do
            it 'exists' do
              expect(on(host, 'firewall-cmd --permanent --info-service=test_thing').output).not_to be_empty
            end

            it 'retains the description' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-description').output.strip).to eq('Random service test')
            end

            it 'has the proper short description' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-short').output.strip).to eq('Short test')
            end

            it 'has the proper ports' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-ports').output.strip).to eq('1235/tcp 1236/tcp')
            end

            it 'has no protocols' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-protocols').output.strip).to be_empty
            end

            it 'has no modules' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-modules').output.strip).to be_empty
            end

            it 'has no destinations' do
              expect(on(host, 'firewall-cmd --permanent --service=test_thing --get-destinations').output.strip).to be_empty
            end
          end
        end
      end

      context 'built-in overrides' do
        let(:manifest) do
          <<-EOM
            firewalld_custom_service{ 'dhcp':
              short            => 'DHCP Override',
              description      => 'The DHCP Defaults are Silly',
              ports            => ['1234/tcp', { 'port' => '1234', 'protocol' => 'udp' }],
              protocols        => ['ip', 'smp'],
              modules          => ['nf_conntrack_tftp', 'nf_conntrack_snmp'],
              ipv4_destination => '1.2.3.4/23',
              ipv6_destination => '::1'
            }
          EOM
        end

        let(:cleanup_manifest) { "firewalld_custom_service{ 'dhcp': ensure => 'absent' }" }

        it 'overrides built-in services' do
          apply_manifest_on(host, manifest, catch_failures: true)
          expect(file_exists_on(host, '/etc/firewalld/services/dhcp.xml')).to be true
        end

        it 'is idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        it 'removes override changes' do
          apply_manifest_on(host, cleanup_manifest, catch_failures: true)
          expect(file_exists_on(host, '/etc/firewalld/services/dhcp.xml')).to be false
        end

        it 'is idempotent' do
          apply_manifest_on(host, cleanup_manifest, catch_changes: true)
        end
      end

      context 'with only protocols' do
        let(:manifest) do
          <<-EOM
            firewalld_custom_service{ 'ospf':
              protocols => ['ospf'],
            }
          EOM
        end

        it 'runs successfully' do
          apply_manifest_on(host, manifest, catch_failures: true)
        end

        it 'is idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        context 'custom service' do
          it 'exists' do
            expect(on(host, 'firewall-cmd --permanent --info-service=ospf').output).not_to be_empty
          end

          it 'has the proper protocol' do
            expect(on(host, 'firewall-cmd --permanent --service=ospf --get-protocols').output.strip).to eq('ospf')
          end

          it 'has no ports' do
            expect(on(host, 'firewall-cmd --permanent --service=ospf --get-ports').output.strip).to be_empty
          end

          it 'has no modules' do
            expect(on(host, 'firewall-cmd --permanent --service=ospf --get-modules').output.strip).to be_empty
          end

          it 'has no destinations' do
            expect(on(host, 'firewall-cmd --permanent --service=ospf --get-destinations').output.strip).to be_empty
          end
        end
      end
    end

    context 'disable firewalld' do
      it 'returns a fact when firewalld is not running' do
        on(host, 'puppet resource service firewalld ensure=stopped')
        expect(pfact_on(host, 'firewalld_version')).to match(%r{^\d})
      end
    end
  end
end
