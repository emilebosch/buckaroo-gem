require './lib/buckaroo/version'

Gem::Specification.new do |s|
  s.name        = 'buckaroo'
  s.version     = Buckaroo::VERSION
  s.date        = '2013-10-24'
  s.summary     = "Buckaroo payment gateway"
  s.description = "Buckaroo payment gateway"
  s.authors     = ["Emile Bosch"]
  s.email       = 'emilebosch@me.com'
  s.files        = Dir.glob('{lib}/**/*') + %w(README.md)
  s.homepage    = 'https://github.com/emilebosch/buckaroo'
  s.license     = 'MIT'

  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'poltergeist'
  s.add_dependency 'rest-client'
end