module Bazaar

	class PaymentProfile

		belongs_to :user, required: false
		belongs_to :geo_address

	end

end
