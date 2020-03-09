require 'spec_helper'
require 'puppet/provider/firewalld'

describe 'firewalld::reload::complete' do
  let(:pre_condition) { 'function assert_private{}' }

  it {
    is_expected.to contain_exec('firewalld::complete-reload').with(path: '/usr/bin:/bin',
                                                                   command: 'firewall-cmd --complete-reload',
                                                                   refreshonly: true,
                                                                   require: 'Class[Firewalld::Reload]')
  }
end
