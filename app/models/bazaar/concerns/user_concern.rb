module Bazaar
	module Concerns

		module UserConcern
			extend ActiveSupport::Concern

			included do

				has_many :transactions

			end


			####################################################
			# Class Methods

			module ClassMethods




			end


			####################################################
			# Instance Methods

		end

	end
end
