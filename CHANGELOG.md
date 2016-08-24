### 3.1.4

Bugfix: `--get-icmptypes` running against `--zone` when it is a global option. https://github.com/crayfishx/puppet-firewalld/issues/86

### 3.1.3

* Bugfix (CRITICAL) : Purging not respecting --noop mode. https://github.com/crayfishx/puppet-firewalld/pull/84
* Bugfix : firewalld_direct_zones with single quotes in the arguments causes a misconfigured XML file.  https://github.com/crayfishx/puppet-firewalld/pull/83

### 3.1.2

* Bugfix: use relative file location for requiring `lib/puppet/type/firewalld_direct_*`, https://github.com/crayfishx/puppet-firewalld/pull/80

### 3.1.1
* Bugfix: use relative file location for requiring `lib/puppet/provider/firewalld`, this addresses https://github.com/crayfishx/puppet-firewalld/issues/78

## 3.1.0

* Feature: firewalld::custom_service now accepts a `filename` parameter, defaults to the value of `short` for backwards compatibility.  Note that this change will be short lived and replaced by a name pattern in 4.0.0.  See issue https://github.com/crayfishx/puppet-firewalld/issues/75
* Multiple fixes to purging of firewalld resources, if enabled, running configuration will always be purged by a firewall restart if there are any resources found to be purgable.  This addresses https://github.com/crayfishx/puppet-firewalld/issues/26
* Bugfix: 2 Puppet runs required to create a custom service and attach to a zone, fixed.  See https://github.com/crayfishx/puppet-firewalld/issues/27
* Bugfix: Added resource chains (as in 2.x) to set relationships between service, resources and the exec to reload firewall, this fixes an issue where resources declared in Puppet (eg: from the profile) do not automatically get their dependencies set.  See https://github.com/crayfishx/puppet-firewalld/issues/38



### 3.0.2
* Bugfix release
* Fixed issue #68, direct_rules and passthroughs badly configured

### 3.0.1
* Puppet forge metadata changes, no functional changes.

# 3.0.0

* BREAK: Puppet manifests now written for the new parser, must use Puppet 4 or 3.x + Future parser
* custom_services now configurable in hiera
* BREAK: #58 Reloads by default now use --reload, not --complete-reload (separate resource provided for that)
* Bugfix #64 : invert => true for source and destinations on rich rules fixed.
* New types and providers for direct chains, rules and passthroughs
* Provider will attempt to call firewall-offline-cmd if an exception is raised suggesting the service is down (see #46)
* Overhaul of internals for the providers
* Many more tests added


## 2.2.0
* #43 firewall-config package is not installed by default, can be enabled with the install_gui param
* #33 Protocol element now managed by firewalld_rich_rile
* #13 ELEMENTS constant changed to a method to stop ruby warnings

# 2.0.0

* Fix: #25 - purge_ports for firewalld_zone now works as expected
* BREAK: port parameter for firewalld_port now only accepts a port, not a hash as previously documented.


