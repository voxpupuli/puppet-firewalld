# == Class: firewalld
#
# Manage the firewalld service
#
# See the README.md for usage instructions for the firewalld_zone and
# firewalld_rich_rule types
#
# === Examples
#
#  Standard:
#    include firewalld
#
#  Command line only, no GUI components:
#    class{'firewalld':
#      packages => ['firewalld']
#    }
#
#
# === Authors
#
# Craig Dunn <craig@craigdunn.org>
#
# === Copyright
#
# Copyright 2015 Craig Dunn
#
#
class firewalld (
  $packages       = [ 'firewalld', 'firewall-config' ],
  $package_ensure = 'installed',
  $service_ensure = 'running',
  $service_enable = true,
) {
    # Type Validation
    validate_array(
      $packages,
    )
    validate_string(
      $package_ensure,
      $service_ensure,
    )
    validate_bool(
      $service_enable,
    )

    # Further validation of string parameters
    if !($package_ensure in ['present','absent','latest','installed']) {
      fail("Parameter package_ensure not set to valid value in module firewalld. Valid values are: present, absent, latest, installed. Value set: ${package_ensure}")
    }
    
    if !($service_ensure in ['stopped','running',]) {
    fail("Parameter service_ensure not set to valid value in module firewalld. Valid values are: stopped, running. Value set: ${service_ensure}")
  }

    package { $packages:
      ensure => $package_ensure,
      notify => Service['firewalld']
    }

    service { 'firewalld':
      ensure => $service_ensure,
      enable => $service_enable,
    }

    exec{ 'firewalld::reload':
      path        =>'/usr/bin:/bin',
      command     => 'firewall-cmd --complete-reload',
      refreshonly => true,
    }

    Service['firewalld'] -> Firewalld_zone <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_rich_rule <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_service <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_port <||> ~> Exec['firewalld::reload']
}
