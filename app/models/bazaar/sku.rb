module Bazaar

	class Sku
		has_many :inventory_logs
		has_many :offer_interval_skus
		has_many :offers, through: :offer_interval_skus

	end

end
