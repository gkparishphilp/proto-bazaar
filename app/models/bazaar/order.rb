module Bazaar

	class Order

		belongs_to :parent, polymorphic: true, required: false
		belongs_to :user, required: false
		belongs_to :payment_profile, required: false
		belongs_to :shipping_address, required: false
		belongs_to :email

	end

end
