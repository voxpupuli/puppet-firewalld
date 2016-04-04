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
#    }
#
#  With GUI components
#    class{'firewalld':
#      install_gui => true,
#    }
#    
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
  $package       = 'firewalld',
  $package_ensure = 'installed',
  $service_ensure = 'running',
  $config_package = 'firewall-config',
  $install_gui    = false,
  $service_enable = true,
  $zones          = {},
  $ports          = {},
  $services       = {},
  $rich_rules     = {},
) {
    # Type Validation
    validate_string(
      $package,
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

    package { $package:
      ensure => $package_ensure,
      notify => Service['firewalld']
    }

    if $install_gui {
      package { $config_package:
        ensure => installed,
      }
    }

    service { 'firewalld':
      ensure => $service_ensure,
      enable => $service_enable,
    }

    exec { 'firewalld::reload':
      path        =>'/usr/bin:/bin',
      command     => 'firewall-cmd --complete-reload',
      refreshonly => true,
    }

    create_resources('firewalld_port',      $ports)
    create_resources('firewalld_zone',      $zones)
    create_resources('firewalld_service',   $services)
    create_resources('firewalld_rich_rule', $rich_rules)

    Service['firewalld'] -> Firewalld_zone <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_rich_rule <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_service <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_port <||> ~> Exec['firewalld::reload']
}
