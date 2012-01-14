# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require File.dirname(__FILE__) + '/version.rb'

Gem::Specification.new do |s|
  s.name        = "alert_machine"
  s.version     = AlertMachine::VERSION
  s.authors     = ["prasanna"]
  s.email       = ["myprasanna@gmail.com"]
  s.homepage    = "http://github.com/likealittle/alert_machine"
  s.summary     = "Ruby way of alerting server events."
  s.description = "Make sure you get mailed when bad things happen to your server."

  s.rubyforge_project = "alert_machine"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "rye"
  s.add_runtime_dependency "actionmailer"
  s.add_runtime_dependency "eventmachine"
end
