# == Type: firewalld::custom_service
#
# Creates a new service definition for use in firewalld
#
# See the README.md for usage instructions for this defined type
#
# === Examples
#
#    firewalld::custom_service{'My Custom Service':
#      short       => 'MyService',
#      description => 'My Custom Service is a daemon that does whatever',
#      port        => [
#        {
#            'port'     => '1234'
#            'protocol' => 'tcp'
#        },
#        {
#            'port'     => '1234'
#            'protocol' => 'udp'
#        },
#      ],
#      module      => ['nf_conntrack_netbios_ns'],
#      destination => {
#        'ipv4' => '127.0.0.1',
#        'ipv6' => '::1'
#      }
#    }
#
# === Authors
#
# Andrew Patik <andrewpatik@gmail.com>
#
#
define firewalld::custom_service (
  $short                = $name,
  $description          = undef,
  $port                 = undef, # Should be an array of hashes
  $module               = undef, # Should be an array of strings
  $destination          = undef,
  $filename             = undef,
  $config_dir           = '/etc/firewalld/services',
  $ensure               = 'present',
) {

  validate_string($short)

  $x_filename = $filename ? {
    undef   => $short,
    default => $filename,
  }

  if $description != undef {validate_string($description)}
  if $module      != undef {validate_array($module)}
  if $port        != undef {validate_array($port)}
  if $destination != undef {
    validate_hash($destination)

    if !has_key($destination, 'ipv4') and !has_key($destination, 'ipv6'){
      fail('Parameter destination must contain at least one of "ipv4" and/or "ipv6" as keys in the hash')
    }
  }
  validate_absolute_path($config_dir)

  file{"${config_dir}/${x_filename}.xml":
    ensure  => $ensure,
    content => template('firewalld/service.xml.erb'),
    mode    => '0644',
    notify  => Exec["firewalld::custom_service::reload-${name}"],
  }

  exec{ "firewalld::custom_service::reload-${name}":
    path        =>'/usr/bin:/bin',
    command     => 'firewall-cmd --reload',
    refreshonly => true,
  }

}
