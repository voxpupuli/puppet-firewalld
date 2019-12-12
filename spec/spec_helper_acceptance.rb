require 'beaker-rspec'
require 'pry'

UNSUPPORTED_PLATFORMS = %w[windows Darwin].freeze

unless ENV['RS_PROVISION'] == 'no' || ENV['BEAKER_provision'] == 'no'

  require 'beaker/puppet_install_helper'

  run_puppet_install_helper('agent', ENV['PUPPET_VERSION'])

  RSpec.configure do |c|
    # Project root
    proj_root = File.expand_path(File.join(__dir__, '..'))

    # Readable test descriptions
    c.formatter = :documentation

    # Don't burn resources if we don't have to
    c.fail_fast = true

    # Configure all nodes in nodeset
    c.before :suite do
      hosts.each do |host|
        install_dev_puppet_module_on(host, source: proj_root, module_name: 'firewalld')
        install_puppet_module_via_pmt_on(host, module_name: 'puppetlabs/stdlib')
      end
    end
  end
end
