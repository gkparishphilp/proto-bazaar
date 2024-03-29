class SwellEcomMigration < ActiveRecord::Migration[5.1]
	def change

		create_table :bazaar_agreements do |t|
			t.references	:user
			t.references	:offer
			t.references	:payment_profile
			t.string 			:code

			t.integer			:quantity, default: 1

			t.integer			:current_interval, default: 1
			t.integer			:max_intervals, default: 1

			t.datetime		:canceled_at, default: nil
			t.datetime		:start_at
			t.datetime		:end_at, default: nil

			t.datetime		:current_interval_start_at
			t.datetime		:next_interval_start_at
			t.datetime		:next_interval_bill_at, default: nil # the next time an agreement will be billed

			t.hstore			:properties, default: {}
			t.timestamps
		end

		create_table :bazaar_agreement_intervals do |t|
			t.references	:agreement
			t.integer 		:start_interval, default: 1
			t.string			:interval_unit
			t.integer			:interval_value
			t.timestamps
		end
		add_index 	:bazaar_agreement_intervals, [:agreement_id, :start_interval], unique: true

		create_table :bazaar_agreement_interval_discounts do |t|
			t.references	:agreement
			t.integer 		:start_interval, default: 1
			t.integer 		:max_intervals, default: 1
			t.references	:discount
			t.timestamps
		end

		# indicates the orders generated for each interval, and which offer was sold.
		# In this way multiple agreements could be put together on the same order.
		create_table :bazaar_agreement_orders do |t|
			t.references	:agreement
			t.references	:order
			t.references	:offer_interval
			t.integer			:interval, default: 1
			t.timestamps
		end
		add_index 	:bazaar_agreement_orders, [:agreement_id, :interval], unique: true

		create_table :bazaar_carts do |t|
			t.references	:user
			t.references	:email
			t.references	:order
			t.integer			:status, default: 1
			t.string			:currency, default: 'USD'
			t.integer			:subtotal, default: 0
			t.integer			:estimated_tax, default: 0
			t.integer			:estimated_shipping, default: 0
			t.integer			:estimated_total, default: 0
			t.string			:ip
			t.json 				:checkout_cache, default: {}
			t.hstore			:properties, default: {}
			t.timestamps
		end

		create_table :bazaar_cart_items do |t|
			t.references	:cart
			t.references	:offer
			t.integer			:quantity
			t.integer			:price
			t.timestamps
		end

		create_table :discount_offer_conditions, force: :cascade do |t|
			t.references	:discount
			t.references	:offer
			t.integer			:min_quantity, default: 1
			t.integer			:max_quantity, default: nil

			t.timestamps
		end

		create_table :discount_product_conditions, force: :cascade do |t|
			t.references	:discount
			t.references	:product
			t.integer			:min_quantity, default: 1
			t.integer			:max_quantity, default: nil

			t.timestamps
		end

		create_table :discounts, force: :cascade do |t|
			t.status	:status, default: 0 # trash => -1, draft => 0, active => 1
			t.string	:type # UnconditionalDiscount, ConditionalDiscount ( Coupon )
			t.json 		:currency_amounts, default: {} # currency (upcased string) => price (int)
			t.float		:percent_amount, default: 0
			t.integer	:discount_type, default: 1 # fixed, fixed_each, percent
			t.string	:discountable_types, array: true, default: nil # offers, shipping, all

			t.string	:code
			t.integer	:max_uses_per_customer, default: nil
			t.integer	:max_uses_global, default: nil
			t.integer	:min_offer_subtotal, default: 0
			t.integer	:max_offer_subtotal, default: nil
			t.integer	:min_shipping_subtotal, default: 0
			t.integer	:max_shipping_subtotal, default: nil
			t.integer	:min_quantity, default: 1
			t.integer	:max_quantity, default: nil
			t.integer	:min_agreement_interval, default: 1
			t.integer	:max_agreement_interval, default: 1

			t.boolean	:order_conditions, default: false
			t.boolean	:product_conditions, default: false
			t.boolean	:offer_conditions, default: false

			t.timestamps
		end

		# can sum on this table to determine current stock levels
		create_table :bazaar_inventory_logs do |t|
			t.references	:shipment, default: nil
			t.references	:sku
			t.integer			:quantity, default: 1,
			t.integer			:status, default: -1, # -1 => pick, 0 => canceled/restock, 1 => stock
			t.text				:notes, default: nil
			t.timestamps
		end

		create_table :bazaar_offers do |t|
			t.references	:product
			t.string			:title
			t.string			:description
			t.string			:slug
			t.integer			:status, default: 1
			t.integer			:max_intervals, default: 1 # nil for infinity
			t.string			:default_interval_unit, default: 'months'
			t.integer			:default_interval_value, default: 1
			t.hstore			:properties, default: {}
			t.integer			:min_quantity, default: 1
			t.integer			:max_quantity, default: nil
			t.datetime		:valid_from
			t.datetime		:valid_to, default: nil
			t.timestamps
		end

		create_table :bazaar_offer_intervals do |t|
			t.references 	:offer
			t.integer 		:start_interval, default: 1
			t.string			:description

			t.string			:interval_unit, default: nil
			t.integer			:interval_value, default: nil

			t.json 				:prices, default: {} # currency (upcased string) => price (int)
			t.timestamps
		end
		add_index 	:bazaar_offer_intervals, [:offer_id, :start_interval], unique: true

		create_table :bazaar_offer_interval_skus do |t|
			t.references 	:offer
			t.integer 		:start_interval, default: 1
			t.integer 		:max_intervals, default: 1
			t.references 	:sku
			t.integer 		:quantity, default: 1
			t.timestamps
		end

		create_table :bazaar_orders do |t|
			t.references	:user
			t.references	:payment_profile
			t.references	:shipping_address
			t.string			:type
			t.references	:parent, polymorphic: true
			t.references	:email
			t.string 			:code
			t.integer			:status, default: 0

			t.string			:ip
			t.string			:created_by, default: 'checkout' # checkout, wholesale, third party ecommerce platform,

			t.string			:currency, default: 'USD'
			t.integer			:subtotal, default: 0
			t.integer			:discount, default: 0
			t.integer			:tax, default: 0
			t.integer			:shipping, default: 0
			t.integer			:total, default: 0

			t.hstore			:properties, default: {}

			t.timestamps
		end

		create_table :bazaar_order_offers do |t|
			t.references	:order
			t.references	:offer_interval
			t.integer			:interval, default: 1
			t.string			:title
			t.integer			:quantity, default: 1
			t.integer			:price, default: 0
			t.integer			:subtotal, default: 0
			t.timestamps
		end

		create_table :bazaar_order_items do |t|
			t.references	:order
			t.references	:item, polymorphic: true
			t.integer			:order_item_type
			t.string			:title
			t.integer			:quantity, default: 1
			t.integer			:price, default: 0
			t.integer			:subtotal, default: 0
			t.timestamps
		end

		create_table :bazaar_payment_profile do |t|
			t.references	:user
			t.references	:geo_address
			t.string			:payment_method # mastercard, visa, amazon pay, ...
			t.string			:descriptor # last 4 of a credit card, ...
			t.string			:provider # the bank or service name
			t.string			:provider_customer_profile_reference
			t.string			:provider_customer_payment_profile_reference
			t.datetime		:expires_at, nil
		end

		create_table :products do |t|
			t.string			:title
			t.string			:brand
			t.string			:model
			t.text				:description
			t.text				:content
			t.string			:avatar
			t.integer			:status, default: 1
			t.integer			:availability, :default: 0
			t.string			:slug
			t.json 				:prices_min, default: {} # currency (upcased string) => price (int)
			t.json 				:prices_max, default: {} # currency (upcased string) => price (int)
			t.string			:tags, default: [], array: true
			t.hstore			:properties, default: {}
			t.datetime		:publish_at, default: nil
			t.timestamps
		end

		create_table :bazaar_shipments do |t|
			t.references	:order, default: nil
			t.integer			:status, default: 0, # canceled, pending, packed, in_transit, delivered, rejected, returned
			t.string			:code

			t.references	:source_geo_address, default: nil
			t.references	:destination_geo_address

			t.string			:fulfilled_by, defaut: 'self' # third party fulfillment service, self, ...
			t.string			:fulfillment_reference_code # a reference code for the for the shipment

			t.string			:courier
			t.string			:courier_status

			t.string			:tracking_code
			t.string			:tracking_url

			t.integer			:cost, defaut: 0
			t.integer			:price

			t.datetime		:estimated_delivered_at, default: nil
			t.datetime		:fulfillment_accepted_at, default: nil
			t.datetime		:packed_at, default: nil
			t.datetime		:in_transit_at, default: nil
			t.datetime		:delivered_at, default: nil
			t.datetime		:returned_at, default: nil

			t.hstore			:properties, default: {}

			t.timestamps
		end

		create_table :bazaar_shipment_logs do |t|
			t.references	:shipment
			t.string			:courier_status
			t.string			:title
			t.string			:description
			t.datetime		:logged_at
			t.hstore			:properties, default: {}
			t.timestamps
		end

		create_table :bazaar_skus do |t|
			t.string		:title
			t.string 		:code
			t.integer		:availability, :default: 0
			t.integer		:stock, default: 0
			t.integer		:shape, default: 0
			t.float			:weight
			t.float			:length
			t.float			:width
			t.float			:height
			t.string		:tariff_code, default: nil
			t.string		:tax_code, default: "00000"
			t.timestamps
		end

		create_table :bazaar_transactions do |t|
			t.references :cart
			t.references :order
			t.references :user
			t.references :agreement
			t.references :payment_profile
			t.integer :transaction_type, default: 1
			t.string :reference_code
			t.integer :amount, default: 0
			t.string :currency, default: "USD"
			t.integer :status, default: 1
			t.text :message
			t.hstore :properties, default: {}
			t.timestamps
		end



	end
end
