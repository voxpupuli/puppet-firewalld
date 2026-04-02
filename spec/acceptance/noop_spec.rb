# frozen_string_literal: true

require 'spec_helper_acceptance'

UNSUPPORTED_PLATFORMS = %w[windows Darwin].freeze

describe 'firewalld noop mode without package installed', unless: UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  hosts.each do |host|
    context "on #{host}" do
      before(:all) do
        # Ensure the firewalld package is absent so we can test noop behaviour
        # when the package has not yet been installed.
        on(host, 'puppet resource package firewalld ensure=absent --logdest syslog', acceptable_exit_codes: [0, 1, 2])
      end

      let(:manifest) do
        <<-EOM
          class { 'firewalld':
            default_zone => 'public',
            log_denied   => 'all',
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
        apply_manifest_on(host, manifest, noop: true, catch_failures: true)
      end

      it 'is idempotent in noop mode' do
        apply_manifest_on(host, manifest, noop: true, catch_changes: true)
      end
    end
  end
end
