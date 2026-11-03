# frozen_string_literal: true

require 'spec_helper_acceptance'

UNSUPPORTED_PLATFORMS = %w[windows Darwin].freeze

describe 'firewalld noop mode without package installed', unless: UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  hosts.each do |host|
    context "on #{host}" do
      before(:all) do
        # Ensure the firewalld package is absent so we can test noop behaviour
        # when the package has not yet been installed.  Stop the service first
        # so the package removal is clean and complete.
        on(host, 'systemctl stop firewalld || true')
        on(host, 'systemctl disable firewalld || true')
        on(host, '(command -v dnf && dnf remove -y firewalld) || (command -v yum && yum remove -y firewalld) || true', acceptable_exit_codes: [0, 1])

        # Fail fast if the test environment is not what we expect.
        cmd = on(host, 'command -v firewall-cmd || true')
        raise 'firewall-cmd is still present after removing firewalld' unless cmd.stdout.strip.empty?
      end

      let(:manifest) do
        <<-EOM
          class { 'firewalld':
            default_zone   => 'public',
            log_denied     => 'all',
            service_ensure => 'stopped',
            service_enable => false,
          }

          firewalld_zone { 'public':
            ensure => 'present',
            target => 'default',
          }

          firewalld_service { 'ssh':
            ensure => 'present',
            zone   => 'public',
          }

          firewalld_port { '8080/tcp':
            ensure   => 'present',
            port     => '8080',
            protocol => 'tcp',
            zone     => 'public',
          }
        EOM
      end

      it 'runs successfully in noop mode when the package is not installed' do
        # In noop mode puppet returns exit code 0 even when resources report
        # 'created (noop)', so we use catch_failures (allows 0 and 2) to
        # verify the run did not encounter a real resource failure.
        apply_manifest_on(host, manifest, noop: true, catch_failures: true)
      end
    end
  end
end
