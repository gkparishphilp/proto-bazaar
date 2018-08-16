module Bazaar

	class InventoryLog

		belongs_to :shipment, required: false
		belongs_to :sku

	end

end
