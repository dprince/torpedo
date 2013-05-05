Gem::Specification.new do |s|
  s.name = %q{torpedo}
  s.version = IO.read('VERSION').chomp

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Dan Prince"]
  s.date = %q{2013-05-02}
  s.default_executable = %q{torpedo}
  s.description = %q{Fast Ruby integration tests for OpenStack.}
  s.email = %q{dprince@redhat.com}
  s.executables = ["torpedo"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    "LICENSE.txt",
    "README.md",
    "bin/torpedo",
    "lib/torpedo.rb",
    "lib/torpedo/compute/flavors.rb",
    "lib/torpedo/compute/helper.rb",
    "lib/torpedo/compute/images.rb",
    "lib/torpedo/compute/limits.rb",
    "lib/torpedo/compute/servers.rb",
    "lib/torpedo/config.rb",
  ]
  s.homepage = %q{http://github.com/dprince/torpedo}
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Fire when ready. Fast Ruby integration tests for OpenStack.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_runtime_dependency(%q<thor>, ["~> 0.14.6"])
      s.add_runtime_dependency(%q<fog>)
      s.add_runtime_dependency(%q<net-ssh>, ["~> 2.2.1"])
    else
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<thor>, ["~> 0.14.6"])
      s.add_dependency(%q<fog>)
      s.add_dependency(%q<net-ssh>, ["~> 2.2.1"])
    end
  else
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<thor>, ["~> 0.14.6"])
    s.add_dependency(%q<fog>)
    s.add_dependency(%q<net-ssh>, ["~> 2.2.1"])
  end
end

