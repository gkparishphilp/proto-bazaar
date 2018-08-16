module Bazaar

	class AgreementOrder

		belongs_to :agreement
		belongs_to :order
		belongs_to :offer_interval

	end

end
