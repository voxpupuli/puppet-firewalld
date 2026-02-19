# frozen_string_literal

require 'puppet/provider/firewalld_dbus'

module DBus
  class Error; end
end

class Puppet::Provider::FirewalldDbus
  def self.version?(_)
    return false
  end

  def self.dbus_interface(_)
    nil
  end
end
