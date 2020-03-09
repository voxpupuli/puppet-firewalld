require 'spec_helper'
require 'puppet/provider/firewalld'

describe 'firewalld::reload' do
  let(:pre_condition) { 'function assert_private{}' }

  it {
    is_expected.to contain_exec('firewalld::reload').with(path: '/usr/bin:/bin',
                                                          command: 'firewall-cmd --reload',
                                                          onlyif: 'firewall-cmd --state',
                                                          refreshonly: true)
  }
end
