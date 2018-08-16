module Bazaar

	class OrderItem

		belongs_to :order
		belongs_to :item, polymorphic: true, required: false

	end

end
