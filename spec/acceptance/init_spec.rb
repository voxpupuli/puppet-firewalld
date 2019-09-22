require 'spec_helper_acceptance'

describe 'firewalld', unless: UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  context 'running with defaults' do
    it 'runs successfully' do
      pp = 'include firewalld'
      # Apply...
      apply_manifest(pp, catch_failures: true)
      # ...twice and see if this is idempotent
      expect(apply_manifest(pp, catch_failures: true).exit_code).to be_zero
    end

    describe command('firewall-cmd --list-ports') do
      its(:stdout) { is_expected.to match %r{6379} }
      its(:stdout) { is_expected.to match %r{5666} }
    end
  end
end
