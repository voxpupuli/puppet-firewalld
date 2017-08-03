### 3.3.2

* Bugfix: Corrected issue with setting default zones on Debian systems running dash instead of bash (https://github.com/crayfishx/puppet-firewalld/pull/144)
* Bugfix: Various typos in error messages fixed (https://github.com/crayfishx/puppet-firewalld/pull/145)
* Bugfix: Fixed issue with `firewalld_zone` provider in later versions of firewalld where the command stops returning a zones sources in alphanumeric order causing issues for Puppet to determine if the resource attribute is in sync (https://github.com/crayfishx/puppet-firewalld/pull/144)
* Bugfix: Fixed issue where `firewalld_zone` did not add `icmp_block` entires on creation, requiring another Puppet run (https://github.com/crayfishx/puppet-firewalld/issues/139)


### 3.3.1

* Bugfix: Dependency fix for adding a default zone in the same puppet run as creating the zone. This solves the issue of firewalld failing to set the default zone because firewalld hasn't reloaded yet and it can't see the zone as active. (https://github.com/crayfishx/puppet-firewalld/issues/135)

## 3.3.0

* Feature: added the `firewalld_ipset` type to manage IPsets (https://github.com/crayfishx/puppet-firewalld/issues/108)
* Feature: added `masquerade` attribute to `firewalld_zone` to manage masquerading on zones (https://github.com/crayfishx/puppet-firewalld/issues/129)
* Feature: added `ipset` option to rich rules source option
* Various documentation bugfixes

### 3.2.1

* Bugfix: Fix for when custom_service ports are defined as integers, (https://github.com/crayfishx/puppet-firewalld/issues/122)
* Documentation fixes

## 3.2.0

* Feature: allow for port ranges to be defined with `custom_service` declarations (https://github.com/crayfishx/puppet-firewalld/issues/107)
* Feature: added `default_zone` to the firewalld base class to allow for a default zone to be defined (https://github.com/crayfishx/puppet-firewalld/pull/118)
* Bugfix: Fix to `firewalld_rich_rule` types when firewalld is in a down state (https://github.com/crayfishx/puppet-firewalld/issues/112)
* Bugfix: Better service  availability checking when purging rules (https://github.com/crayfishx/puppet-firewalld/issues/101)
* Bugfix: Handle later versions of firewalld where the target is returned as `REJECT` instead of `%%REJECT%%` - this is a backwards compatible fix (https://github.com/crayfishx/puppet-firewalld/issues/111)
* Numerous documentation typo fixes

### 3.1.8

* Bugfix: Change how types and providers reference other providers by referencing the `Puppet::Type` API rather than trying to load them with `require`.  This addresses some intermitent problems with Puppets autoloading and registering of types that caused exceptions in Puppet 4.5.0+ in some circumstances, depending on the ordering of the manifest evaluation.  See https://github.com/crayfishx/puppet-firewalld/issues/93 and https://tickets.puppetlabs.com/browse/PUP-6922

* Documentation fixes (#100)

### 3.1.7

* Bugfix: This release addresses an issue configuring firewalld on a system where the package is not yet installed.  The logic used to determine the state of the firewall is run before the package provider can install the package causing catalog application to fail. Fixed https://github.com/crayfishx/puppet-firewalld/issues/96

### 3.1.6

* Bugfix: #94.  puppet types generate failed with the following error

```
Error: /etc/puppetlabs/code/environments/production/modules/firewalld/lib/puppet/type/firewalld_direct_chain.rb: title patterns that use procs are not supported.
```

Since procs are not actually needed in this title pattern they have been removed to stop this error.


### 3.1.5

* Bugfix: #90 - `firewalld_service` fails to remove services in offline mode. see https://github.com/crayfishx/puppet-firewalld/issues/90
* Internal: Provider tests for the state of firewalld on initiation to decide which command to use (`firewall-cmd` or `firewall-offline-cmd`) rather than relying on catching an exception in `execute_firewall()`


### 3.1.4

* Bugfix: `--get-icmptypes` running against `--zone` when it is a global option. https://github.com/crayfishx/puppet-firewalld/issues/86

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


