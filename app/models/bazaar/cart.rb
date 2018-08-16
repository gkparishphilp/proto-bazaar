module Bazaar

	class Cart

		belongs_to :user, required: false
		belongs_to :email, required: false
		belongs_to :order, required: false

	end

end
