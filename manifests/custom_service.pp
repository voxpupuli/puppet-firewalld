# @summary Creates a new service definition for use in firewalld
#
# **DEPRECATED**: Please use the `firewalld_custom_service` native type moving forward
#
# This defined type will be removed in a future release
#
# @example
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
# Andrew Patik <andrewpatik@gmail.com>
# Trevor Vaughan <tvaughan@onyxpoint.com>
#
define firewalld::custom_service (
  String                   $short       = $name,
  Optional[String]         $description = undef,
  Optional[Array[Hash]]    $port        = undef,
  Optional[Array[String]]  $module      = undef,
  Optional[Hash[
      Enum['ipv4', 'ipv6'],
      String
  ]]                       $destination = undef,
  String                   $filename    = $short,
  Stdlib::Unixpath         $config_dir  = '/etc/firewalld/services',
  Enum['present','absent'] $ensure      = 'present',
) {
  $_args = delete_undef_values( {
      'ensure'           => $ensure,
      'short'            => $short,
      'description'      => $description,
      'ports'            => $port,
      'modules'          => $module,
      'ipv4_destination' => $destination.dig('ipv4'),
      'ipv6_destination' => $destination.dig('ipv6'),
  })

  $_safe_filename = firewalld::safe_filename($filename)

  # Remove legacy files so that we don't end up with conflicts
  #
  # This functionality will be removed in a future release
  unless $_safe_filename == $short {
    file { "${config_dir}/${short}.xml":
      ensure => absent,
    }
  }

  firewalld_custom_service { $_safe_filename:
    * => $_args,
  }
}
