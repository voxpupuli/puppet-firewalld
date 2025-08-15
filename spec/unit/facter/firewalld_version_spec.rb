# frozen_string_literal: true

require 'spec_helper'

describe 'firewalld_version' do
  before do
    Facter.clear

    allow(Process).to receive(:uid).and_return(0)
    allow(Facter::Core::Execution).to receive(:exec).with('uname -s').and_return('Linux')
    allow(Facter::Util::Resolution).to receive(:which).with('firewall-offline-cmd').and_return('/usr/bin/firewall-offline-cmd')
    allow(Facter::Core::Execution).to receive(:execute).with('/usr/bin/firewall-offline-cmd --version', on_fail: :failed).and_return(firewalld_version.dup)
  end

  let(:python_args) do
    %{-c 'import firewall.config; print(firewall.config.__dict__["VERSION"])'}
  end

  context 'as a regular user' do
    let(:firewalld_version) { "0.7.0\n" }

    it 'does not return a fact' do
      allow(Process).to receive(:uid).and_return(1)

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
      allow(Facter::Util::Resolution).to receive(:which).with('python').and_return('/usr/bin/python')
      allow(Facter::Core::Execution).to receive(:execute).with("/usr/bin/python #{python_args}", on_fail: :failed).and_return(:failed)

      expect(Facter.fact('firewalld_version').value).to be_nil
    end
  end
end
