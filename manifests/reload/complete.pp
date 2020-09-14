# @summary A common point for triggering an intermediary firewalld full reload using firewall-cmd
#
class firewalld::reload::complete {
  assert_private()

  include firewalld::reload

  exec { 'firewalld::complete-reload':
    path        => '/usr/bin:/bin',
    command     => 'firewall-cmd --complete-reload',
    refreshonly => true,
    require     => Class['firewalld::reload'],
  }
}
