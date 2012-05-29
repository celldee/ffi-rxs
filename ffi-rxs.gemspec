# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ffi-rxs/version"

Gem::Specification.new do |s|
  s.name        = "ffi-rxs"
  s.version     = XS::VERSION
  s.authors     = ["Chris Duncan"]
  s.email       = ["celldee@gmail.com"]
  s.homepage    = "http://github.com/celldee/ffi-rxs"
  s.summary     = %q{Ruby FFI bindings for Crossroads I/O messaging library.}
  s.description = %q{Ruby FFI bindings for Crossroads I/O messaging library.}

  s.files         = `git ls-files`.split("\n")
  s.files         = s.files.reject{ |f| f.include?('ext/libxs.so') }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "ffi", [">= 1.0.10"]
  s.add_development_dependency "rspec", ["~> 2.6"]
  s.add_development_dependency "rake"
end
