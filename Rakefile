# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "torpedo"
  gem.executables = "torpedo"
  gem.homepage = "http://github.com/dprince/torpedo"
  gem.license = "MIT"
  gem.summary = %Q{Fire when ready. Fast Ruby integration tests for OpenStack.}
  gem.description = %Q{Fast integration tests for OpenStack.}
  gem.email = "dprince@redhat.com"
  gem.authors = ["Dan Prince"]
  # dependencies defined in Gemfile
  gem.add_dependency 'thor', '~>0.14.6'
  gem.add_dependency 'fog'
  gem.add_dependency('net-ssh', '~>2.2.1')
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  #test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

=begin
require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
  test.rcov_opts << '--exclude "gems/*"'
end
=end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "torpedo #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
