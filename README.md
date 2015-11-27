# Module: firewalld

[![Build Status](https://travis-ci.org/crayfishx/puppet-firewalld.svg?branch=master)](https://travis-ci.org/crayfishx/puppet-firewalld)  [![Join the chat at https://gitter.im/crayfishx/puppet-firewalld](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/crayfishx/puppet-firewalld?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Description

This module manages firewalld, the userland interface that replaces iptables and ships with RHEL7.  The module manages firewalld itself as well as providing types and providers for managing firewalld zones, ports, and rich rules.

## Usage

The firewalld module contains types and providers to manage zones, services, ports, and rich rules by interfacing with the `firewall-cmd` command.  The following types are currently supported.  Note that all zone, service, port, and rule management is done in `--permanent` mode, and a complete reload will be triggered anytime something changes.

### Firewalld Zones

Firewalld zones can be managed with the `firewalld_zone` resource type.

_Example_:

```puppet
  firewalld_zone { 'restricted':
    ensure           => present,
    target           => '%%REJECT%%',
    purge_rich_rules => true,
    purge_services   => true,
    purge_ports      => true,
  }
```

#### Parameters

* `target`: Specify the target of the zone.
* `purge_rich_rules`: Optional, and defaulted to false.  When true any configured rich rules found in the zone that do not match what is in the Puppet catalog will be purged.
* `purge_services`: Optional, and defaulted to false.  When true any configured services found in the zone that do not match what is in the Puppet catalog will be purged. *Warning:* This includes the default ssh service, if you need SSH to access the box, make sure you add the service through either a rich firewall rule, port, or service (see below) or you will lock yourself out!
* `purge_ports`: Optional, and defaulted to false. When true any configured ports found in the zone that do not match what is in the Puppet catalog will be purged. *Warning:* As with services, this includes the default ssh port. If you fail to specify the appropriate port, rich rule, or service, you will lock yourself out.

### Firewalld rich rules

Firewalld rich rules are managed using the `firewalld_rich_rule` resource type

firewalld_rich_rules will `autorequire` the firewalld_zone specified in the `zone` parameter so there is no need to add dependencies for this

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

### Firewalld Custom Service

The `firewalld::custom_service` defined type creates and manages custom services. It makes the service usable by firewalld, but does not add it to any zones. To do that, use the firewalld::service type.

_Example_:

```puppet
    firewalld::custom_service{'Custom service for application XYZ':
      short       => 'XZY',
      description => 'XZY is a daemon that does whatever',
      port        => [
        {
            'port'     => '1234',
            'protocol' => 'tcp',
        },
        {
            'port'     => '1234',
            'protocol' => 'udp',
        },
      ],
      module      => ['nf_conntrack_netbios_ns'],
      destination => {
        'ipv4' => '127.0.0.1',
        'ipv6' => '::1'
      }
    }
```

This resource will create the following XML service definition in /etc/firewalld/services/XZY.xml
```
    <?xml version="1.0" encoding="utf-8"?>
    <service>
      <short>XZY</short>
      <description>XZY is a daemon that does whatever</description>
      <port protocol="tcp" port="1234" />
      <port protocol="udp" port="1234" />
      <module name="nf_conntrack_netbios_ns"/>
      <destination ipv4="127.0.0.1" ipv6="::1"/>
    </service>
```
and you will also see 'XZY' in the service list when you issue ```firewall-cmd --permanent --get-services```

#### Parameters

* `short`: (namevar) The short name of the service (what you see in the firewalld command line output)

* `description`: (Optional) A short description of the service

* `port`: (Optional) The protocol / port definitions for this service. Specified as an array of hashes, where each hash defines a protocol and/or port associated with this service. Each hash requires both port and protocol keys, even if the value is an empty string. Specifying a port only works for TCP & UDP, otherwise leave it empty and the entire protocol will be allowed. Valid protocols are tcp, udp, or any protocol defined in /etc/protocols
  ```puppet
     port => [{'port' => '1234', 'protocol' => 'tcp'}],

     port => [{'port' => '4321', 'protocol' => 'udp'}, {'protocol' => 'rdp'}],
  ```

* `module`: (Optional) An array of strings specifying netfilter kernel helper modules associated with this service

* `destination`: (Optional) A hash specifying the destination network as a network IP address (optional with /mask), or a plain IP address. Valid hash keys are 'ipv4' and 'ipv6', with values corresponding to the IP / mask associated with each of those protocols. The use of hostnames is possible but not recommended, because these will only be resolved at service activation and transmitted to the kernel.
  ```puppet
     destination => {'ipv4' => '127.0.0.1', 'ipv6' => '::1'},

     destination => {'ipv4' => 192.168.0.0/24'},
  ```

* `config_dir`: The location where the service definition XML files will be stored. Defaults to /etc/firewalld/services

### Firewalld Service

The `firewalld_service` type is used to add or remove both built in and custom services from zones.

firewalld_service will `autorequire` the firewalld_zone specified in the `zone` parameter and the firewalld::custom_service
specified in the `service` parameter, so there is no need to add dependencies for this

_Example_:

```puppet
  firewalld_service { 'Allow SSH from the external zone':
    ensure  => 'present',
    service => 'ssh',
    zone    => 'external
  }
```

#### Parameters

* `service`: Name of the service to manage

* `zone`: Name of the zone in which you want to manage the service

### Firewalld Ports

Firewalld ports can be managed with the `firewalld_port` resource type.

firewalld_port will `autorequire` the firewalld_zone specified in the `zone` parameter so there is no need to add dependencies for this

_Example_:

```puppet
  firewalld_port { 'Open port 8080 in the public zone':
    ensure   => present,
    zone     => 'public',
    port     => 8080,
    protocol => 'tcp',
  }
```

#### Parameters

* `zone`: Name of the zone this port belongs to

* `port`: A hash containing `port` and `protocol` values
```puppet
  port => {
    'port' => 8080,
    'protocol' => 'tcp',
  },
```

## Limitations / TODO (PR's welcome!)

* Currently only _target_ and _icmp_blocks_ are managable properties for a zone
* services can only be assigned to one zone per resource declaration. We would like to add support for specifying multiple zones as an array.

## Author

* Written and maintained by Craig Dunn <craig@craigdunn.org> @crayfisx
* Sponsered by Baloise Group [http://baloise.github.io](http://baloise.github.io)
