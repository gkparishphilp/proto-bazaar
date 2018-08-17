require 'paypal-sdk-rest'

module Bazaar
	module Services
		module Transaction
			class PayPalExpressCheckoutTransactionService < Bazaar::TransactionService

				PROVIDER_NAME = 'PayPalExpressCheckout'

				def initialize( args = {} )
					raise Exception.new('add "gem \'paypal-sdk-rest\'" to your Gemfile') unless defined?( PayPal::SDK )

					@client_id		= args[:client_id] || ENV['PAYPAL_EXPRESS_CHECKOUT_CLIENT_ID']
					@client_secret	= args[:client_secret] || ENV['PAYPAL_EXPRESS_CHECKOUT_CLIENT_SECRET']
					@mode			= args[:mode] || ENV['PAYPAL_EXPRESS_CHECKOUT_MODE'] || 'sandbox' # or 'live'

					@provider_name	= args[:provider_name] || PROVIDER_NAME
				end



				def capture_payment_method( order, args = {} )
					return false
				end

				def process( order, args = {} )

					payer_id = args[:pay_pal][:payer_id]
					payment_id = args[:pay_pal][:payment_id]

					PayPal::SDK.configure(
						:mode => @mode,
						:client_id => @client_id,
						:client_secret => @client_secret,
						# :ssl_options => { }
					)

					# order.payment_status = 'payment_method_captured'
					order.provider = @provider_name

					order.provider_customer_profile_reference = payer_id
					order.provider_customer_payment_profile_reference = payment_id

					if payment_id.present? && payer_id.present? && ( payment = PayPal::SDK::REST::Payment.find(payment_id) ).present?

						payment_amount = ( payment.transactions.sum{|transaction| transaction.amount.total.to_f } * 100 ).to_i

					    if payment.error

							NewRelic::Agent.notice_error( Exception.new("PayPalExpressCheckout Payment Error: #{payment.error}") ) if defined?( NewRelic )
							order.errors.add(:base, :processing_error, message: "Transaction declined.")

						elsif not( ((order.total-1)..(order.total+1)).include?( payment_amount ) )

							NewRelic::Agent.notice_error( Exception.new("PayPal checkout amount does not match invoice. #{payment_amount} vs #{order.total}") ) if defined?( NewRelic )
							puts "PayPal checkout amount does not match invoice. #{payment_amount} vs #{order.total}" if @mode == 'sandbox'
							order.errors.add(:base, :processing_error, message: "PayPal checkout amount does not match invoice.")

						elsif payment.execute( payer_id: payer_id )

							transaction = Bazaar::Transaction.create( transaction_type: 'charge', reference_code: payment_id, customer_profile_reference: payer_id, customer_payment_profile_reference: payment_id, provider: @provider_name, amount: order.total, currency: order.currency, status: 'approved' )

							order.payment_status = 'paid'

							if order.save

								transaction.update( parent_obj: order )

								return transaction

							end


						else

							order.errors.add(:base, :processing_error, message: "Transaction declined.")

						end

					else

						NewRelic::Agent.notice_error( Exception.new("PayPalExpressCheckout Payment Error: Payer and/or payment id not present") ) if defined?( NewRelic )
						order.errors.add(:base, :processing_error, message: "Invalid PayPal Credentials.")

					end


					return false
				end

				def provider_name
					@provider_name
				end

				def refund( args = {} )

					# assumes :amount, and :charge_transaction
					charge_transaction	= args.delete( :charge_transaction )
					parent_obj			= charge_transaction.parent_obj

					raise Exception.new('unable to find transaction') if charge_transaction.nil?

					# Generate Refund transaction
					transaction = Bazaar::Transaction.new( args )
					transaction.transaction_type	= 'refund'
					transaction.provider			= @provider_name
					transaction.amount				= args[:amount]
					transaction.amount				||= charge_transaction.amount
					transaction.currency			= parent_obj.currency
					transaction.parent_obj			= parent_obj

					if transaction.amount <= 0
						transaction.status = 'declined'
						transaction.errors.add(:base, "Refund amount must be greater than 0")
						return transaction
					end

					# Fetch paypal payment object for original sale
					payment = PayPal::SDK::REST::Payment.find(charge_transaction.reference_code)
					payment_obj = JSON.parse( payment.to_json, symbolize_names: true )

					# Find sale in from payment object
					transaction_obj = payment_obj[:transactions].first
					if transaction_obj.present? && transaction_obj[:related_resources].present?
						sale_obj = transaction_obj[:related_resources].select{|resource| resource[:sale].present? }.first
					end
					sale = PayPal::SDK::REST::Sale.find( sale_obj[:sale][:id] ) if sale_obj.present?

					# Use the sale to process a refund
					if sale.present?

						refund_obj = {
							:amount => {
								:total => "#{'%.2f' % transaction.amount_as_money}",
								:currency => transaction.currency.upcase
							}
						}

						refund = sale.refund( refund_obj )

						if refund.error

							transaction.status = 'declined'
							transaction.message = refund.error
							# transaction.errors.add(:base, "Refuned failed")

						else

							transaction.status = 'approved'
							transaction.reference_code = refund.id

						end

						transaction.save!

					else
						transaction.status = 'declined'
						transaction.errors.errors.add(:base, "Unable to find corresponding sale")
					end

					return transaction
				end

				def update_subscription_payment_profile( subscription, args = {} )
					return false
				end


			end
		end
	end
end
