require 'spec_helper_acceptance'

describe 'firewalld', :unless => UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do

  context 'running with defaults' do
    it 'should run successfully' do
      pp = "include firewalld"
      #Apply...
      apply_manifest(pp, :catch_failures =>true)
      #...twice and see if this is idempotent
      expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
    end
  end
end
