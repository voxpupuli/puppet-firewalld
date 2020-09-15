# @summary Manage the firewalld service
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
# === Authors
#
# Craig Dunn <craig@craigdunn.org>
#
# === Copyright
#
# Copyright 2015 Craig Dunn
#
class firewalld (
  Enum['present','absent','latest','installed']                 $package_ensure            = 'installed',
  String                                                        $package                   = 'firewalld',
  Stdlib::Ensure::Service                                       $service_ensure            = 'running',
  String                                                        $config_package            = 'firewall-config',
  Boolean                                                       $install_gui               = false,
  Boolean                                                       $service_enable            = true,
  Hash                                                          $zones                     = {},
  Hash                                                          $ports                     = {},
  Hash                                                          $services                  = {},
  Hash                                                          $rich_rules                = {},
  Hash                                                          $custom_services           = {},
  Hash                                                          $ipsets                    = {},
  Hash                                                          $direct_rules              = {},
  Hash                                                          $direct_chains             = {},
  Hash                                                          $direct_passthroughs       = {},
  Boolean                                                       $purge_direct_rules        = false,
  Boolean                                                       $purge_direct_chains       = false,
  Boolean                                                       $purge_direct_passthroughs = false,
  Boolean                                                       $purge_unknown_ipsets      = false,
  Optional[String]                                              $default_zone              = undef,
  Optional[Enum['off','all','unicast','broadcast','multicast']] $log_denied                = undef,
  Optional[Enum['yes', 'no']]                                   $cleanup_on_exit           = undef,
  Optional[Enum['yes', 'no']]                                   $zone_drifting             = undef,
  Optional[Integer]                                             $minimal_mark              = undef,
  Optional[Enum['yes', 'no']]                                   $lockdown                  = undef,
  Optional[Enum['yes', 'no']]                                   $ipv6_rpfilter             = undef,
  Optional[Enum['iptables', 'nftables']]                        $firewall_backend          = undef,
  Optional[String]                                              $default_service_zone      = undef,
  Optional[String]                                              $default_port_zone         = undef,
  Optional[String]                                              $default_port_protocol     = undef,
) {
  include firewalld::reload
  include firewalld::reload::complete

  package { $package:
    ensure => $package_ensure,
    notify => Service['firewalld'],
  }

  if $install_gui {
    package { $config_package:
      ensure => installed,
    }
  }

  Exec {
    path => '/usr/bin:/bin',
  }

  service { 'firewalld':
    ensure => $service_ensure,
    enable => $service_enable,
  }

  # create ports
  Firewalld_port {
    zone      => $default_port_zone,
    protocol  => $default_port_protocol,
  }

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
  Firewalld_service {
    zone      => $default_service_zone,
  }

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

  #...ipsets
  $ipsets.each | String $key, Hash $attrs| {
    firewalld_ipset { $key:
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
    notify => Class['firewalld::reload'],
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

  if $default_zone {
    exec { 'firewalld::set_default_zone':
      command => "firewall-cmd --set-default-zone ${default_zone}",
      unless  => "[ $(firewall-cmd --get-default-zone) = ${default_zone} ]",
      require => Service['firewalld'],
    }

    Firewalld_zone <||> -> Exec['firewalld::set_default_zone']
  }

  if $log_denied {
    exec { 'firewalld::set_log_denied':
      command => "firewall-cmd --set-log-denied ${log_denied}",
      unless  => "[ $(firewall-cmd --get-log-denied) = ${log_denied} ]",
      require => Service['firewalld'],
    }
  }

  Augeas {
    lens    => 'Shellvars.lns',
    incl    => '/etc/firewalld/firewalld.conf',
    notify => [
      Class['firewalld::reload'],
      Service['firewalld'],
    ],
  }

  if $cleanup_on_exit {
    augeas {
      'firewalld::cleanup_on_exit':
        changes => [
          "set CleanupOnExit \"${cleanup_on_exit}\"",
        ];
    }
  }

  if $zone_drifting {
    augeas {
      'firewalld::zone_drifting':
        changes => [
          "set AllowZoneDrifting \"${zone_drifting}\"",
        ];
    }
  }

  if $minimal_mark {
    augeas {
      'firewalld::minimal_mark':
        changes => [
          "set MinimalMark \"${minimal_mark}\"",
        ];
    }
  }

  if $lockdown {
    augeas {
      'firewalld::lockdown':
        changes => [
          "set Lockdown \"${lockdown}\"",
        ];
    }
  }

  if $ipv6_rpfilter {
    augeas {
      'firewalld::ipv6_rpfilter':
        changes => [
          "set IPv6_rpfilter \"${ipv6_rpfilter}\"",
        ];
    }
  }

  if $facts['firewalld_version'] and
  (versioncmp($facts['firewalld_version'], '0.6.0') >= 0) and
  $firewall_backend {
    augeas {
      'firewalld::firewall_backend':
        changes => [
          "set FirewallBackend \"${firewall_backend}\"",
        ];
    }
  }

  # TODO: Replace these with a native firewalld_reload type and automatically
  # hook the types together properly.
  Firewalld_direct_chain <||> ~> Class['firewalld::reload']
  Firewalld_direct_passthrough <||> ~> Class['firewalld::reload']
  Firewalld_direct_purge <||> ~> Class['firewalld::reload']
  Firewalld_direct_rule <||> ~> Class['firewalld::reload']
  Firewalld_ipset <||> ~> Class['firewalld::reload']
  Firewalld_port <||> ~> Class['firewalld::reload']
  Firewalld_rich_rule <||> ~> Class['firewalld::reload']
  Firewalld_service <||> ~> Class['firewalld::reload']

  if $purge_unknown_ipsets {
    Firewalld_ipset <||>
    ~> resources { 'firewalld_ipset':
      purge => true,
    }
  }
}
