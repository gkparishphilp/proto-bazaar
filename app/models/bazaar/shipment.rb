module Bazaar

	class Shipment

		belongs_to :order, required: false
		belongs_to :source_geo_address, required: false
		belongs_to :destination_geo_address

		has_many :shipment_logs
		has_many :inventory_logs

	end

end
