module Bazaar
	module TransactionService

		def calculate( order, args = {} )

			order.total = order.order_items.to_a.sum(&:subtotal) + order.order_offers.to_a.sum(&:subtotal)

		end

		def process( order, args = {} )
		end

		def validate( order, args = {} )
			# validate billing address/payment details
		end

	end
end
