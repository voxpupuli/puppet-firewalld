
include firewalld

firewalld_zone { 'restricted':
  ensure           => present,
  target           => '%%REJECT%%',
  purge_rich_rules => true,
}

