module Bazaar

	class Shipment

		belongs_to :order, required: false
		belongs_to :source_geo_address, required: false
		belongs_to :destination_geo_address

	end

end
