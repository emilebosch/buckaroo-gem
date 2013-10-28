require 'rake/testtask'
require './lib/buckaroo/version'

Rake::TestTask.new do |t|
  t.libs << "lib/buckaroo.rb"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :uninstall do
  puts 'Unintalling..'
  `gem uninstall buckaroo -ax`
  `rbenv rehash`
end

task :install => :uninstall  do
  `rm *.gem`
  `gem build buckaroo.gemspec`
  `gem install --local veda-#{Buckaroo::VERSION}.gem`
  `rbenv rehash`
end

task :default => :test