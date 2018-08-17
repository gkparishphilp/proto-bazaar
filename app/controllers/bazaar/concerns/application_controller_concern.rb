module Bazaar
	module Concerns

		module ApplicationControllerConcern
			extend ActiveSupport::Concern

			included do

				before_action	:get_cart
				
			end


			####################################################
			# Class Methods

			module ClassMethods




			end


			####################################################
			# Instance Methods

			protected

				def get_cart

				end

		end

	end
end
