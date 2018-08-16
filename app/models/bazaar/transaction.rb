module Bazaar

	class Transaction

			belongs_to :cart, required: false
			belongs_to :order, required: false
			belongs_to :user, required: false
			belongs_to :agreement, required: false
			belongs_to :payment_profile

	end

end
