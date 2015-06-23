# == Class: firewalld
#
# Manage the firewalld service
#
# See the README.md for usage instructions for the firewalld_zone and
# firewalld_rich_rule types
#
# === Examples
#
#  include firewalld
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
  $package_config = true,
){

    validate_bool($package_config)

    package { 'firewalld':
      ensure => installed,
    }

    if ($package_config){
      $_package_config = 'installed'
    } else {
      $_package_config = 'absent'
    }
    package { 'firewall-config':
      ensure => $_package_config,
    }

    service { 'firewalld':
      ensure    => running,
      enable    => true,
      subscribe => Package['firewalld'],
    }

    exec{ 'firewalld::reload':
      path        =>'/usr/bin:/bin',
      command     => 'firewall-cmd --complete-reload',
      refreshonly => true,
    }

    Service['firewalld'] -> Firewalld_zone <||> ~> Exec['firewalld::reload']
    Service['firewalld'] -> Firewalld_rich_rule <||> ~> Exec['firewalld::reload']
}

