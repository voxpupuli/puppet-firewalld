require 'spec_helper'

describe 'firewalld_version' do
  before do
    Facter.clear

    Process.stubs(:uid).returns(0)
    Facter::Core::Execution.stubs(:exec).with('uname -s').returns('Linux')
    Facter::Util::Resolution.stubs(:which).with('firewall-offline-cmd').returns('/usr/bin/firewall-offline-cmd')
    Facter::Core::Execution.stubs(:execute).with('/usr/bin/firewall-offline-cmd --version', on_fail: :failed).returns(firewalld_version)
  end

  let(:python_args) do
    %{-c 'import firewall.config; print(firewall.config.__dict__["VERSION"])'}
  end

  context 'as a regular user' do
    let(:firewalld_version) { "0.7.0\n" }

    it 'does not return a fact' do
      Process.stubs(:uid).returns(1)

      expect(Facter.fact('firewalld_version').value).to be_nil
    end
  end

  context 'firewall-cmd succeeds' do
    let(:firewalld_version) { "0.7.0\n" }

    it 'returns a valid version' do
      expect(Facter.fact('firewalld_version').value).to eq(firewalld_version.strip)
    end
  end

  context 'firewall-cmd fails' do
    let(:firewalld_version) { :failed }

    it 'does not return a fact' do
      Facter::Util::Resolution.stubs(:which).with('python').returns('/usr/bin/python')
      Facter::Core::Execution.stubs(:execute).with("/usr/bin/python #{python_args}", on_fail: :failed).returns(:failed)

      expect(Facter.fact('firewalld_version').value).to be_nil
    end
  end
end
