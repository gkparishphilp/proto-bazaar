module Bazaar

	class Order

		belongs_to :parent, polymorphic: true, required: false
		belongs_to :user, required: false
		belongs_to :payment_profile, required: false
		belongs_to :shipping_address, required: false
		belongs_to :email

		has_many :order_items
		has_many :order_offers
		has_many :transactions
		has_many :shipments

		has_many :agreement_orders
		has_many :agreements, throught: :agreement_orders

		def has_errors?
		end

	end

end
