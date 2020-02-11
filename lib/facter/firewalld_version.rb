# Return the version of firewalld that is installed
Facter.add(:firewalld_version) do
  confine { Process.uid.zero? }

  @firewall_cmd = Facter::Util::Resolution.which('firewall-cmd')
  confine { @firewall_cmd }

  setcode do
    Facter::Core::Execution.execute(%(#{@firewall_cmd} --version), on_fail: :failed).strip
  end
end
