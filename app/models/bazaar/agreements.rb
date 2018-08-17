module Bazaar

	class Agreement

		belongs_to :user
		belongs_to :offer
		belongs_to :payment_profile

		has_many :agreement_intervals
		has_many :agreement_interval_discounts
		has_many :agreement_orders
		has_many :orders, throught: :agreement_orders

		has_many :transactions

	end

end
