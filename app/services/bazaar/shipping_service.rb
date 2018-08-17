module Bazaar
	module ShippingService

		def build_shipment( order, args = {} )
			return nil if order.shipping_address.blank?

			shipment = order.shipments.new( destination_geo_address: order.shipping_address )
			order.order_offers.each do |order_offer|
				order_offer.offer_interval.offer.offer_skus.for_interval( order_offer.interval ).each do |offer_sku|
					shipment.inventory_logs.new( sku: offer_sku.sku, quantity: order_offer.quantity * offer_sku.quantity )
				end
			end

			shipment
		end

		def calculate( order, args = {} )
			shipment = build_shipment( order )
			calculate_shipment( shipment, args )
			order.shipping = order.shipments.collect(&:price).sum
			order
		end

		def calculate_shipment( shipment, args = {} )
		end

		def process( order, args = {} )
		end

		def validate( order, args = {} )
			# validate shipping address
		end

	end
end
