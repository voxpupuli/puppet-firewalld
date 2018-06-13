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
  String $short                   = $name,
  Optional[String] $description   = undef,
  Optional[Array[Hash]] $port     = undef,
  Optional[Array[String]] $module = undef,
  Optional[Hash[
    Enum['ipv4', 'ipv6'],
    String
  ]] $destination                 = undef,
  String $filename                = $short,
  Stdlib::Unixpath $config_dir    = '/etc/firewalld/services',
  Enum['present',
    'absent'
  ] $ensure                       = 'present',
) {

  file{"${config_dir}/${filename}.xml":
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
