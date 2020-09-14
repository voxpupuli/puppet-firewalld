# @summary A common point for triggering an intermediary firewalld reload using firewall-cmd
#
class firewalld::reload {
  assert_private()

  exec { 'firewalld::reload':
    path        => '/usr/bin:/bin',
    command     => 'firewall-cmd --reload',
    onlyif      => 'firewall-cmd --state',
    refreshonly => true,
  }
}
