Gem::Specification.new do |s|
  s.name        = "couchchanges"
  s.version     = "0.1"
  s.date        = "2010-07-14"
  s.summary     = "ruby consumer for couchdb's _changes api"
  s.email       = "harry@vangberg.name"
  s.homepage    = "http://github.com/ichverstehe/couchchanges"
  s.description = "ruby consumer for couchdb's _changes api"
  s.authors     = ["Harry Vangberg"]
  s.files = [
    "README",
		"couchchanges.gemspec",
    "Rakefile",
		"lib/couchchanges.rb",
  ]
  s.test_files = Dir.glob("test/test_*.rb")

  s.add_dependency "em-http-request", ">= 0.2.7"
  s.add_dependency "json"

  s.add_development_dependency "contest"
  s.add_development_dependency "eventmachine"
  s.add_development_dependency "couchrest"
end

