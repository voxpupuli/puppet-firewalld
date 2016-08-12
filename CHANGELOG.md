## 3.0.2
* Bugfix release
* Fixed issue #68, direct_rules and passthroughs badly configured

## 3.0.1
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


# 2.2.0
* #43 firewall-config package is not installed by default, can be enabled with the install_gui param
* #33 Protocol element now managed by firewalld_rich_rile
* #13 ELEMENTS constant changed to a method to stop ruby warnings

# 2.0.0

* Fix: #25 - purge_ports for firewalld_zone now works as expected
* BREAK: port parameter for firewalld_port now only accepts a port, not a hash as previously documented.


