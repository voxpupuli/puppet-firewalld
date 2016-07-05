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
  $package         = 'firewalld',
  $package_ensure  = 'installed',
  $service_ensure  = 'running',
  $config_package  = 'firewall-config',
  $install_gui     = false,
  $service_enable  = true,
  $zones           = {},
  $ports           = {},
  $services        = {},
  $rich_rules      = {},
  $custom_services = {},
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

    # Merge hashes from multiple layer of hierarchy in hiera
    # ports
    $hiera_ports = hiera_hash("${module_name}::ports",undef)
    $fin_ports = $hiera_ports ? {
      undef   => $ports,
      default => $hiera_ports,
    }
    # zones
    $hiera_zones = hiera_hash("${module_name}::zones",undef)
    $fin_zones = $hiera_zones ? {
      undef   => $zones,
      default => $hiera_zones,
    }
    # services
    $hiera_services = hiera_hash("${module_name}::services",undef)
    $fin_services = $hiera_services ? {
      undef   => $services,
      default => $hiera_services,
    }
    # rich rules
    $hiera_rich_rules = hiera_hash("${module_name}::rich_rules",undef)
    $fin_rich_rules = $hiera_rich_rules ? {
      undef   => $rich_rules,
      default => $hiera_rich_rules,
    }
    # custom services
    $hiera_custom_services = hiera_hash("${module_name}::custom_services",undef)
    $fin_custom_services = $hiera_custom_services ? {
      undef   => $custom_services,
      default => $hiera_custom_services,
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

    create_resources('firewalld_port',      $fin_ports)
    create_resources('firewalld_zone',      $fin_zones)
    create_resources('firewalld_service',   $fin_services)
    create_resources('firewalld_rich_rule', $fin_rich_rules)
    create_resources('firewalld::custom_service', $fin_custom_services)

    Service['firewalld'] -> Firewalld_zone <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_rich_rule <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_service <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_port <||> ~> Exec['firewalld::reload']
}
