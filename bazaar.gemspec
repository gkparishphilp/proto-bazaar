$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "bazaar/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "bazaar"
  s.version     = Bazaar::VERSION
  s.authors     = ["Michael Ferguson", "Gk Parish-Philp"]
  s.email       = ["meister+support@spacekace.com"]
  s.homepage    = "http://spacekace.com"
  s.summary     = "an e-commerce engine for rails"
  s.description = "an e-commerce engine for rails"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  # s.test_files = Dir["test/**/*"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency 'jbuilder'
  s.add_dependency 'rest-client'

  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rails-controller-testing'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency "sqlite3"
end
