# frozen_string_literal: true

# Return the version of firewalld that is installed
Facter.add(:firewalld_version) do
  confine { Process.uid.zero? }

  @firewall_cmd = Facter::Core::Execution.which('firewall-offline-cmd')
  confine { @firewall_cmd }

  setcode do
    def failed_value?(value)
      !value || (value == :failed) || value.empty?
    end

    value = Facter::Core::Execution.execute(%(#{@firewall_cmd} --version), on_fail: :failed)

    if failed_value?(value)
      # Python gets stuck in some weird places
      python = Facter::Core::Execution.which('python')
      python ||= Facter::Core::Execution.which('platform-python')

      python_path = '/usr/libexec/platform-python'
      python ||= python_path if File.exist?(python_path)

      # Because firewall-cmd fails if firewalld is not running
      workaround_command = %{#{python} -c 'import firewall.config; print(firewall.config.__dict__["VERSION"])'}

      value = Facter::Core::Execution.execute(workaround_command, on_fail: :failed)
    end

    if failed_value?(value)
      value = nil
    else
      value.strip!
    end

    value
  end
end
