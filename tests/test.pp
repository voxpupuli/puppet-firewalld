
class { 'firewalld':
  default_zone => 'restricted',
}

firewalld_zone { 'restricted':
  ensure           => present,
  target           => '%%REJECT%%',
  purge_rich_rules => true,
}

