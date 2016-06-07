require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'pry'

UNSUPPORTED_PLATFORMS = %W('windows', 'Darwin').freeze

unless ENV['RS_PROVISION'] == 'no' || ENV['BEAKER_provision'] == 'no'

  environment = ENV['http_proxy'] ? { http_proxy:  ENV['http_proxy'] } : {}

  run_puppet_install_helper

  RSpec.configure do |c|
    # Project root
    proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    # Readable test descriptions
    c.formatter = :documentation

    # Configure all nodes in nodeset
    c.before :suite do
      puppet_module_install(source: proj_root, module_name: 'firewalld')
      hosts.each do |host|
        scp_to(host, File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec/fixtures/hiera/hiera.yaml')), '/etc/puppetlabs/code/hiera.yaml')
        scp_to(host, File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec/fixtures/hieradata/')), '/etc/puppetlabs/code/environments/production/')
        on host, '/opt/puppetlabs/bin/puppet module install puppetlabs/stdlib', environment: environment, acceptable_exit_codes: [0, 1]
      end
    end
  end
end
