module Bazaar

	class PaymentProfile

		belongs_to :user, required: false
		belongs_to :geo_address
		
		has_many :transactions

	end

end
