
include firewalld

firewalld_zone { 'testcraig':
  ensure => present,
  target => '%%REJECT%%',
  purge_rich_rules => true,
}

