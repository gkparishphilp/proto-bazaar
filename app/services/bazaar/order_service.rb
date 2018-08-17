module Bazaar
	module OrderService

		def initialize( options = {} )
			@agreement_service = ApplicationAgreementService.new
			@discount_service = ApplicationDiscountService.new
			@fraud_service = ApplicationFraudService.new
			@shipping_service = ApplicationShippingService.new
			@tax_service = ApplicationTaxService.new
			@transaction_service = ApplicationTransactionService.new
		end

		def calculate( order, options = {} )

			options[:agreement] ||= {}
			options[:discount] ||= {}
			options[:fraud] ||= {}
			options[:shipping] ||= {}
			options[:tax] ||= {}
			options[:transaction] ||= {}

			order.validate
			self.validate( order )
			@agreement_service.validate( order, options[:agreement] )
			@fraud_service.validate( order, options[:fraud] )
			@discount_service.calculate( order, options[:discount].merge( state: :pre_shipping ) ) unless order.has_errors?
			@shipping_service.calculate( order, options[:shipping] ) unless order.has_errors?
			@discount_service.calculate( order, options[:discount].merge( state: :pre_tax ) ) unless order.has_errors?
			@tax_service.calculate( order, options[:tax] ) unless order.has_errors?
			@discount_service.calculate( order, options[:discount] ) unless order.has_errors?
			@transaction_service.calculate( order, options[:transaction] ) unless order.has_errors?

		end

		def process( order, options = {} )
			self.calculate( order, options )

			@transaction_service.process( order, options[:transaction] ) unless order.has_errors?

			if order.has_errors?
				false
			else
				@tax_service.process( order, options[:tax] )
				@shipping_service.process( order, options[:shipping] )
				@agreement_service.process( order, options[:agreement] )
				true
			end
		end

		def agreement_service
			@agreement_service
		end

		def discount_service
			@discount_service
		end

		def fraud_service
			@fraud_service
		end

		def shipping_service
			@shipping_service
		end

		def tax_service
			@tax_service
		end

		def transaction_service
			@transaction_service
		end

		def validate( order )
		end

	end
end
