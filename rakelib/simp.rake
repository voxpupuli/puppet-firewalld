begin
  require 'simp/rake/beaker'

  Simp::Rake::Beaker.new(File.join(File.dirname(__FILE__), '..'))
rescue LoadError
  $stderr.puts('simp-beaker-helpers not loaded, some acceptance test functionality may be missing')
end
