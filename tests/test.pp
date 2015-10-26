

firewalld_zone { 'testcraig':
  ensure => present,
  target => '%%REJECT%%',
}

firewalld_zone { 'restricted':
  ensure => present,
  target => '%%REJECT%%',
}



firewalld_rich_rule { 'Accept SSH from my box':
  ensure  => present,
  family  => 'ipv4',
  zone    => 'restricted',
  source  => {
    'address' => '10.0.1.2/24'
  },
  service => 'ssh',
  # log => true,
  log     => {
    'level' => 'debug'
  },
  action  => 'accept',
}

# rule family="ipv4" source address="192.168.245.158/32" service name="ssh" accept

firewalld_rich_rule { 'Already exists':
  ensure  => present,
  family  => 'ipv4',
  zone    => 'restricted',
  source  => {
    'address' => '192.168.245.158/32'
  },
  service => 'ssh',
  log     => true,
  action  => 'accept',
}

firewalld_rich_rule { 'Already exists II':
  ensure  => present,
  family  => 'ipv4',
  zone    => 'restricted',
  source  => '192.77.55.4/34',
  service => 'ssh',
  action  => 'accept',
}




#vfirewall-cmd --add-rich-rule='rule family="ipv6" source address="1:2:3:4:6::" forward-port to-addr="1::2:3:4:7" to-port="4012" protocol="tcp" port="4011"'

#firewalld_rich_rule { 'another test':
#  ensure => present,
#  family => 'ipv4',
#  source => { 'address' => '10.9.1.2' },
#  zone   => 'restricted',
#  forward_port => {
#    'to_addr' => '1.2.2.4',
#    'to_port' => '4012',
#    'protocol' => 'tcp',
#    'port' => '929'
#  },
# }
#  
#  
