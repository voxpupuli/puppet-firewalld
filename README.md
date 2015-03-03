# Module: firewalld

## Description

This module manages firewalld, the userland interface that replaces iptables and ships with RHEL7.  The module manages firewalld itself as well as providing types and providers for managing firewalld zones and rich rules. 

## Usage

The firewalld module contains types and providers to manage zones and rich rules by interfacing with the `firewall-cmd` command.  The following types are currently supported.  Note that all zone and rules management is done in `--permanent` mode.

### Firewalld Zones

Firewalld zones can be managed with the `firewalld_zone` resource type.

_Example_:

```puppet
  firewalld_zone { 'restricted':
    ensure => present,
    target => '%%REJECT%%',
    purge_rich_rules => true,
  }
```

#### Parameters

* `target`: Specify the target of the zone
* `purge_rich_rules`: Optional, and defaulted to false.  When true any configured rich rules found in the zone that do not match what is in the Puppet catalog will be purged.

### Firewalld rich rules

Firewalld rich rules are managed using the `firewalld_rich_rule` resource type

firewalld_rich_rules will `autorequire` the firewalld_zone specified in the `zone` parameter so there is no need to add dependancies for this  

_Example_:

```puppet
  firewalld_rich_rule { 'Accept SSH from barny':
    ensure => present,
    zone   => 'restricted',
    source => '192.168.1.2/32',
    service => 'ssh',
    action  => 'accept',
  }
```

#### Parameters

* `zone`: Name of the zone this rich rule belongs to

* `family`: Protocol family, defaults to `ipv4`

* `source`: Source address information. This can be a hash containing the keys `address` and `invert`, or a string containing just the IP address
  ```puppet
     source => '192.168.2.1',

     source => { 'address' => '192.168.1.1', 'invert' => true }
  ```

* `dest`: Source address information. This can be a hash containing the keys `address` and `invert`, or a string containing just the IP address
  ```puppet
     dest => '192.168.2.1',
  
     dest => { 'address' => '192.168.1.1', 'invert' => true }
  ```

* `log`: When set to `true` will enable logging, optionally this can be hash with `prefix`, `level` and `limit`
  ```puppet
     log => { 'level' => 'debug', 'prefix' => 'foo' },
  
     log => true,
  ```

* `audit`: When set to `true` will enable auditing, optionally this can be hash with `limit`
  ```puppet
     audit => { 'limit' => '3/s' },
  
     audit => true,
  ```

* `action`: A string containing the action `accept`, `reject` or `drop`.  For `reject` it can be optionally supplied as a hash containing `type`
  ```puppet
     action => 'accept'
  
     action => { 'action' => 'reject', 'type' => 'bad' }
  ```


The following paramters are the element of the rich rule, only _one_ may be used.

* `service`: Name of the service

* `port`: A hash containing `port` and `protocol` values
  ```puppet
     port => {
       'port' => 80,
       'protocol' => 'tcp',
     },
  ```

* `icmp_block`: Specify an `icmp-block` for the rule

* `masquerade`: Set to `true` or `false` to enable masquerading

* `forward_port`: Set forward-port, this should be a hash containing `port`,`protocol`,`to_port`,`to_addr`
  ```puppet
     forward_port => {
       'port' => '8080',
       'protocol' => 'tcp',
       'to_addr' => '10.2.1.1',
       'to_port' => '8993'
     },
  ```

## Limitations / TODO (PR's welcome!)

* Currently only _target_ is a managable property for a zone

## Author

* Written and maintained by Craig Dunn <craig@craigdunn.org> @crayfisx
* Sponsered by Baloise Group [http://baloise.github.io](http://baloise.github.io)
