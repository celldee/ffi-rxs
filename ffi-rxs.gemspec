# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ffi-rxs/version"

Gem::Specification.new do |s|
  s.name        = "ffi-rxs"
  s.version     = XS::VERSION
  s.authors     = ["Chris Duncan"]
  s.email       = ["celldee@gmail.com"]
  s.homepage    = "http://github.com/celldee/ffi-rxs"
  s.summary     = %q{This gem wraps the Crossroads-IO (Xio) networking library using Ruby FFI (foreign function interface).}
  s.description = %q{This gem wraps the Crossroads-IO networking library using the ruby FFI (foreign
function interface). It's a pure ruby wrapper so this gem can be loaded
and run by any ruby runtime that supports FFI. That's all of them:
MRI 1.9.x, Rubinius and JRuby.}

  # s.rubyforge_project = "ffi-rxs"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "ffi"#, [">= 1.0.9"]
  s.add_development_dependency "rspec", ["~> 2.6"]
  s.add_development_dependency "rake"
end
