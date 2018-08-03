
# require 'stripe'
# require 'tax_cloud'

module Bazaar


	class << self

	end

	# this function maps the vars from your app into your engine
	def self.configure( &block )
		yield self
	end



	class Engine < ::Rails::Engine
		isolate_namespace Bazaar
		config.generators do |g|
			g.test_framework :rspec, :fixture => false
			g.fixture_replacement :factory_girl, :dir => 'spec/factories'
			g.assets false
			g.helper false
		end
	end
end
