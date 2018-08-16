module Bazaar

	class Agreement

		belongs_to :user
		belongs_to :offer
		belongs_to :payment_profile

	end

end
