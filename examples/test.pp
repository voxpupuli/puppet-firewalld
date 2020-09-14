class { 'firewalld':
  log_denied => 'multicast',
}

firewalld_zone { 'restricted':
  ensure           => present,
  target           => '%%REJECT%%',
  purge_rich_rules => true,
}

firewalld_rich_rule { 'McAffee':
  ensure => present,
  source => '10.10.10.50',
  port   => {
    'port'     => 8803,
    'protocol' => 'tcp',
  },
  zone   => 'public',
  action => 'accept',
}
