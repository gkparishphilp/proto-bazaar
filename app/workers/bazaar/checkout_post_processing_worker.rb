module Bazaar

	class CheckoutPostProcessingWorker

		def perform( order_id )
			begin
				order_service = ApplicationOrderService.new
				fraud_service = ApplicationFraudService.new
				agreement_service = ApplicationAgreementService.new

				order = Bazaar::Order.find order_id

				order_service.post_processing( order )
				fraud_service.mark_for_review( order ) if fraud_service.suspicious?( order )
				agreement_service.process( order )
				OrderMailer.receipt( order ).deliver_now

			rescue Exception => e
				puts "OrderPostProcessingWorker FAILURE"
				raise e if Rails.env.development?
				NewRelic::Agent.notice_error(e) if defined?( NewRelic )
			end
		end

	end

end
