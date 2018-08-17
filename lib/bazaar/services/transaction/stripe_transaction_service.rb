module Bazaar
	module Services
		module Transaction
			class StripeTransactionService < Bazaar::TransactionService

				def initialize( args = {} )
					raise Exception.new('add "gem \'stripe\'" to your Gemfile') unless defined?( Stripe )
					@provider_name = args[:provider_name] || 'Stripe'
				end

				def capture_payment_method( order, args = {} )
					# @todo
					throw Exception.new('@todo StripeTransactionService#capture_payment_method')

				end

				def process( order, args = {} )
					self.calculate( order )
					return false if order.nested_errors.present?

					stripe_token = args[:stripeToken]

					begin

						# Token is created using Stripe.js or Checkout!
						# Get the payment token submitted by the form:

						customer = Stripe::Customer.create(
							'email' => order.email,
							'card'  => stripe_token
						)

						# @todo process subscription if order includes a plan, do something different
						# Charge the user's card:
						charge = Stripe::Charge.create(
							'customer'		=> customer.id,
							'amount' 		=> order.total,
							'description' 	=> args[:description] || "#{SwellMedia.app_name} order of #{order.order_items.first.title}".truncate(255),
							'currency'		=> order.currency.downcase,
						)


						if charge.present?

							order.payment_status = 'paid'

							order.save

							Transaction.create( parent_obj: order, transaction_type: 'charge', reference_code: charge.id, provider: @provider_name, amount: order.total, currency: order.currency, status: 'approved' )

							return true
						end



					rescue Stripe::CardError => e

						puts e
						order.errors.add(:base, :processing_error, message: "cannot be nil")
						# Transaction.create( parent: order, transaction_type: 'charge', reference: charge.id, provider: @provider_name, amount: order.total, currency: order.currency, status: 'declined' )

					rescue Stripe::InvalidRequestError => e

						order.errors.add(:base, :processing_error, message: 'Processing error')
						NewRelic::Agent.notice_error(e, custom_params: {
							'e.message' => e.message,
							'email' => order.email,
							'card'  => stripe_token,
							'amount' 	=> order.total,
							'currency'	=> order.currency.downcase,
						} )
						puts e

					end

					return false

				end

				def provider_name
					@provider_name
				end

				def refund( args = {} )
					# @todo
					throw Exception.new('@todo StripeTransactionService#refund')

				end

				def update_subscription_payment_profile( subscription )
					# @todo
					throw Exception.new('@todo StripeTransactionService#update_subscription_payment_profile')

				end

			end

		end

	end

end
