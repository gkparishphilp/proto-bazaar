module Bazaar

	class Offer

		belongs_to :product

		has_many :offer_intervals
		has_many :offer_interval_skus

	end

end
