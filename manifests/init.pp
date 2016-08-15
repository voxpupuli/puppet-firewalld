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
  Enum[
    'present',
    'absent',
    'latest',
    'installed'
  ]       $package_ensure            = 'installed',
  String  $package                   = 'firewalld',
  Enum[
    'stopped',
    'running'
  ]       $service_ensure            = 'running',
  String  $config_package            = 'firewall-config',
  Boolean $install_gui               = false,
  Boolean $service_enable            = true,
  Hash    $zones                     = {},
  Hash    $ports                     = {},
  Hash    $services                  = {},
  Hash    $rich_rules                = {},
  Hash    $custom_services           = {},
  Hash    $direct_rules              = {},
  Hash    $direct_chains             = {},
  Hash    $direct_passthroughs       = {},
  Boolean $purge_direct_rules        = false,
  Boolean $purge_direct_chains       = false,
  Boolean $purge_direct_passthroughs = false
) {

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
      command     => 'firewall-cmd --reload',
      refreshonly => true,
    }

    exec { 'firewalld::complete-reload':
      path        =>'/usr/bin:/bin',
      command     => 'firewall-cmd --complete-reload',
      refreshonly => true,
      require     => Exec['firewalld::reload'],
    }

    # create ports
    $ports.each |String $key, Hash $attrs| {
      firewalld_port { $key:
        *       => $attrs,
      }
    }

    #...zones
    $zones.each | String $key, Hash $attrs| {
      firewalld_zone { $key:
        *       => $attrs,
      }
    }

    #...services
    $services.each | String $key, Hash $attrs| {
      firewalld_service { $key:
        *       => $attrs,
      }
    }

    #...rich rules
    $rich_rules.each | String $key, Hash $attrs| {
      firewalld_rich_rule { $key:
        *       => $attrs,
      }
    }

    #...custom services
    $custom_services.each | String $key, Hash $attrs| {
      firewalld::custom_service { $key:
        *       => $attrs,
      }
    }

    # Direct rules, chains and passthroughs
    $direct_chains.each | String $key, Hash $attrs| {
      firewalld_direct_chain { $key:
        *       => $attrs,
      }
    }

    $direct_rules.each | String $key, Hash $attrs| {
      firewalld_direct_rule { $key:
        *       => $attrs,
      }
    }

    $direct_passthroughs.each | String $key, Hash $attrs| {
      firewalld_direct_passthrough { $key:
        *       => $attrs,
      }
    }

    Firewalld_direct_purge {
      notify => Exec['firewalld::reload'],
    }

    if $purge_direct_chains {
      firewalld_direct_purge { 'chain': }
    }
    if $purge_direct_rules {
      firewalld_direct_purge { 'rule': }
    }
    if $purge_direct_passthroughs {
      firewalld_direct_purge { 'passthrough': }
    }

    # Set dependencies using resource chaining so that resource declarations made
    # outside of this class (eg: from the profile) also get their dependencies set
    # automatically, this addresses various issues found in
    # https://github.com/crayfishx/puppet-firewalld/issues/38
    #
    Service['firewalld'] -> Firewalld_zone <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_rich_rule <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_service <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_port <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_direct_chain <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_direct_rule <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_direct_passthrough <||> ~> Exec['firewalld::reload']

}
