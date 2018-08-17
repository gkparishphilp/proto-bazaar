module Bazaar
	module TaxService


		def initialize( options = {} )
			@options = options
		end

		def calculate( obj, args = {} )

			return self.calculate_order( obj ) if obj.is_a? Order
			return self.calculate_cart( obj ) if obj.is_a? Cart

		end

		def process( order, args = {} )
			return false # or true
		end

		def calculate_cart( cart )
			return
		end

		def calculate_order( order )
			return
		end

	end
end
