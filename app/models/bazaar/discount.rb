module Bazaar

	class Discount

		has_many :discount_offer_conditions
		has_many :discount_product_conditions

	end

end
