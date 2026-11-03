# frozen_string_literal: true

# The noop-safety checks use Puppet::Util.which to detect whether the
# firewall-cmd / firewall-offline-cmd binaries are present.  Unit tests must
# not pass or fail just because the host that runs the suite happens to have
# (or lack) the firewalld package, so we normalize the answer here.
RSpec.configure do |config|
  config.before do
    allow(Puppet::Util).to receive(:which).and_call_original
    allow(Puppet::Util).to receive(:which).with('firewall-cmd').and_return('/usr/bin/firewall-cmd')
    allow(Puppet::Util).to receive(:which).with('firewall-offline-cmd').and_return('/usr/bin/firewall-offline-cmd')
  end
end
