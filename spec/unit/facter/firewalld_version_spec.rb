require 'spec_helper'

describe 'firewalld_version' do
  before do
    Facter.clear

    Process.stubs(:uid).returns(0)
    Facter::Core::Execution.stubs(:exec).with('uname -s').returns('Linux')
    Facter::Util::Resolution.stubs(:which).with('firewall-cmd').returns('/usr/bin/firewall-cmd')
    Facter::Core::Execution.stubs(:execute).with('/usr/bin/firewall-cmd --version', on_fail: :failed).returns(firewalld_version)
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
      expect(Facter.fact('firewalld_version').value).to be_nil
    end
  end
end
