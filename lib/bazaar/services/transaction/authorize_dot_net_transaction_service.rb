# require 'authorizenet'
require 'credit_card_validations'

module Bazaar
	module Services
		module Transaction
			class AuthorizeDotNetTransactionService < Bazaar::TransactionService

				PROVIDER_NAME = 'Authorize.net'
				ERROR_DUPLICATE_CUSTOMER_PROFILE = 'E00039'
				ERROR_DUPLICATE_CUSTOMER_PAYMENT_PROFILE = 'E00039'
				ERROR_INVALID_PAYMENT_PROFILE = 'E00003'
				CANNOT_REFUND_CHARGE = 'E00027'

				WHITELISTED_ERROR_MESSAGES = [ 'The credit card has expired' ]

				def initialize( args = {} )
					raise Exception.new('add "gem \'authorizenet\'" to your Gemfile') unless defined?( AuthorizeNet )

					@api_login	= args[:API_LOGIN_ID] || ENV['AUTHORIZE_DOT_NET_API_LOGIN_ID']
					@api_key	= args[:TRANSACTION_API_KEY] || ENV['AUTHORIZE_DOT_NET_TRANSACTION_API_KEY']
					@gateway	= ( args[:GATEWAY] || ENV['AUTHORIZE_DOT_NET_GATEWAY'] || :sandbox ).to_sym
					@enable_debug = not( Rails.env.production? ) || ENV['AUTHORIZE_DOT_NET_DEBUG'] == '1' || @gateway == :sandbox
					@provider_name = args[:provider_name] || "#{PROVIDER_NAME}-#{@api_login}"
				end

				def capture_payment_method( order, args = {} )
					credit_card_info = args[:credit_card]

					self.calculate( order )
					return false if order.nested_errors.present?

					profiles = get_order_customer_profile( order, credit_card: credit_card_info )
					return false if profiles == false

					order.payment_status = 'payment_method_captured'
					order.provider = @provider_name
					order.provider_customer_profile_reference = profiles[:customer_profile_reference]
					order.provider_customer_payment_profile_reference = profiles[:customer_payment_profile_reference]

					return order if order.save
					return false
				end

				def process( order, args = {} )
					credit_card_info = args[:credit_card]

					self.calculate( order )
					return false if order.nested_errors.present?

					profiles = get_order_customer_profile( order, credit_card: credit_card_info )
					return false if profiles == false

					order.payment_status = 'payment_method_captured'
					order.provider = @provider_name
					order.provider_customer_profile_reference = profiles[:customer_profile_reference]
					order.provider_customer_payment_profile_reference = profiles[:customer_payment_profile_reference]

					anet_order = nil

					# create capture
					anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )
					amount = order.total / 100.0 # convert cents to dollars
					response = anet_transaction.create_transaction_auth_capture( amount, profiles[:customer_profile_reference], profiles[:customer_payment_profile_reference], anet_order )
					direct_response = response.direct_response


					# raise Exception.new("create auth capture error: #{response.message_text}") unless response.success?

					puts response.xml if @enable_debug

					# process response
					if response.success? && direct_response.success?

						# if capture is successful, save order, and create transaction.
						order.payment_status = 'paid'

						if order.save

							# update any subscriptions with profile ids

							transaction = Bazaar::Transaction.create( parent_obj: order, transaction_type: 'charge', reference_code: direct_response.transaction_id, customer_profile_reference: profiles[:customer_profile_reference], customer_payment_profile_reference: profiles[:customer_payment_profile_reference], provider: @provider_name, amount: order.total, currency: order.currency, status: 'approved' )

							if credit_card_info.present?

								credit_card_dector = CreditCardValidations::Detector.new( credit_card_info[:card_number] )

								new_properties = {
									'credit_card_ending_in' => credit_card_dector.number[-4,4],
									'credit_card_brand' => credit_card_dector.brand,
								}

								transaction.properties = transaction.properties.merge( new_properties ) if transaction.respond_to?( :properties )

								transaction.save

							end

							# sanity check
							raise Exception.new( "Bazaar::Transaction create errors #{transaction.errors.full_messages}" ) if transaction.errors.present?

							return transaction

						end

					else

						puts response.xml if @enable_debug

						order.payment_status = 'declined'

						transaction = Transaction.new(
							transaction_type: 'charge',
							reference_code: direct_response.try(:transaction_id),
							customer_profile_reference: profiles[:customer_profile_reference],
							customer_payment_profile_reference: profiles[:customer_payment_profile_reference],
							provider: @provider_name,
							amount: order.total,
							currency: order.currency,
							status: 'declined',
							message: response.message_text,
						)
						transaction.parent_obj ||= args[:default_parent_obj]
						transaction.parent_obj ||= order.user if order.user.persisted?
						transaction.save

						if WHITELISTED_ERROR_MESSAGES.include? response.message_text
							order.errors.add(:base, :processing_error, message: response.message_text )
						else
							order.errors.add(:base, :processing_error, message: "Transaction declined.")
						end


						return transaction
					end


					return false
				end

				def provider_name
					@provider_name
				end

				def refund( args = {} )
					# assumes :amount, and :charge_transaction
					charge_transaction	= args.delete( :charge_transaction )
					parent				= args.delete( :order ) || args.delete( :parent )
					charge_transaction	||= Transaction.where( parent_obj: parent ).charge.first if parent.present?
					anet_transaction_id = args.delete( :transaction_id )

					raise Exception.new( "charge_transaction must be an approved charge." ) unless charge_transaction.nil? || ( charge_transaction.charge? && charge_transaction.approved? )

					transaction = Bazaar::Transaction.new( args )
					transaction.transaction_type	= 'refund'
					transaction.provider			= @provider_name

					if charge_transaction.present?

						transaction.currency			||= charge_transaction.currency
						transaction.parent_obj			||= charge_transaction.parent_obj

						transaction.customer_profile_reference ||= charge_transaction.customer_profile_reference
						transaction.customer_payment_profile_reference ||= charge_transaction.customer_payment_profile_reference

						transaction.amount = charge_transaction.amount unless args[:amount].present?

						anet_transaction_id ||= charge_transaction.reference_code

					elsif anet_transaction_id.present?

						charge_transaction = Bazaar::Transaction.charge.approved.find_by( provider: @provider_name, reference_code: anet_transaction_id )

					end

					raise Exception.new('unable to find transaction') if anet_transaction_id.nil?

					if transaction.amount <= 0
						transaction.status = 'declined'
						transaction.errors.add(:base, "Refund amount must be greater than 0")
						return transaction
					end

					# convert cents to dollars
					refund_dollar_amount = transaction.amount / 100.0

					anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )
					response = anet_transaction.create_transaction_refund(
						anet_transaction_id,
						refund_dollar_amount,
						transaction.customer_profile_reference,
						transaction.customer_payment_profile_reference
					)

					puts response.xml if @enable_debug

					if response.message_code == CANNOT_REFUND_CHARGE
						# if you cannot refund it, that means the origonal charge
						# hasn't been settled yet, so you...

						if transaction.amount == charge_transaction.amount
							# have to void (but only if the refund is for the total amount)
							transaction.transaction_type = 'void'
							anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )
							response = anet_transaction.create_transaction_void(anet_transaction_id)

							puts response.xml if @enable_debug
						else
							# OR create a refund that is unlinked to the transaction
							anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )
							# anet_transaction.set_fields(:trans_id => nil)
							anet_transaction.create_transaction(
								:refund,
								refund_dollar_amount,
								transaction.customer_profile_reference,
								transaction.customer_payment_profile_reference,
								nil, #order
								{}, #options
							)

							# response = anet_transaction.create_transaction_refund(
							# 	nil,
							# 	refund_dollar_amount,
							# 	transaction.customer_profile_reference,
							# 	transaction.customer_payment_profile_reference
							# )

						end
					end

					direct_response = response.direct_response

					# process response
					if response.success? && direct_response.success?

						transaction.status = 'approved'
						transaction.reference_code = direct_response.transaction_id

						# if capture is successful, create transaction.
						transaction.save

						# update corresponding order to a payment status of refunded
						transaction.parent_obj.update payment_status: 'refunded'

						# sanity check
						# raise Exception.new( "Bazaar::Transaction create errors #{transaction.errors.full_messages}" ) if transaction.errors.present?
					else
						puts response.xml if @enable_debug

						NewRelic::Agent.notice_error(Exception.new( "Authorize.net Transaction Error: #{response.message_code} - #{response.message_text}" )) if defined?( NewRelic )

						transaction.status = 'declined'
						transaction.message = response.message_text
						transaction.save

						# sanity check
						# raise Exception.new( "Bazaar::Transaction create errors #{transaction.errors.full_messages}" ) if transaction.errors.present?

					end

					transaction
				end

				def update_subscription_payment_profile( subscription, args = {} )
					payment_profile = request_payment_profile( subscription.user, subscription.billing_address, args[:credit_card], errors: subscription.errors, ip: subscription.order.ip )

					return false unless payment_profile

					credit_card_dector = CreditCardValidations::Detector.new( args[:credit_card][:card_number] )

					new_properties = {
						'credit_card_ending_in' => credit_card_dector.number[-4,4],
						'credit_card_brand' => credit_card_dector.brand,
					}

					subscription.provider = @provider_name
					subscription.provider_customer_profile_reference = payment_profile[:customer_profile_reference]
					subscription.provider_customer_payment_profile_reference = payment_profile[:customer_payment_profile_reference]
					subscription.properties = subscription.properties.merge( new_properties )
					subscription.payment_profile_expires_at	= Bazaar::TransactionService.parse_credit_card_expiry( args[:credit_card][:expiration] ) if subscription.respond_to?(:payment_profile_expires_at)

					subscription.save

				end

				protected

				def get_order_customer_profile( order, args = {} )

					if args[:credit_card].present?

						payment_profile = request_payment_profile( order.user, order.billing_address, args[:credit_card], email: order.email, errors: order.errors, ip: order.ip )

						return payment_profile if payment_profile && order.nested_errors.blank?

					else
						return { customer_profile_reference: order.provider_customer_profile_reference, customer_payment_profile_reference: order.provider_customer_payment_profile_reference } if order.provider_customer_profile_reference.present?

						raise Exception.new( 'cannot create payment profile without credit card info' )

					end

					return false
				end


				def request_payment_profile( user, billing_address, credit_card, args={} )
					anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )
					errors = args[:errors]

					ip_address = args[:ip] if args[:ip].present?
					ip_address ||= user.try(:ip) if user.try(:ip).present?

					billing_address_state = billing_address.state
					billing_address_state = billing_address.geo_state.try(:abbrev) if billing_address_state.blank?
					billing_address_state = billing_address.geo_state.try(:name) if billing_address_state.blank?

					street_address = billing_address.street
					street_address = "#{street_address}\n#{billing_address.street2}" if billing_address.street2.present?

					anet_billing_address = AuthorizeNet::Address.new(
						:first_name		=> billing_address.first_name,
						:last_name		=> billing_address.last_name,
						# :company		=> nil,
						:street_address	=> street_address,
						:city			=> billing_address.city,
						:state			=> billing_address_state,
						:zip			=> billing_address.zip,
						:country		=> billing_address.geo_country.name,
						:phone			=> billing_address.phone,
					)

					# VALIDATE Credit card number
					credit_card_dector = CreditCardValidations::Detector.new(credit_card[:card_number])
					unless credit_card_dector.valid?
						errors.add( :base, 'Invalid Credit Card Number' ) if errors
						return false
					end

					# VALIDATE Credit card expirey
					expiration_time = Bazaar::TransactionService.parse_credit_card_expiry( credit_card[:expiration] )
					if expiration_time.nil?
						errors.add( :base, 'Credit Card Expired is required') if errors
						return false
					elsif expiration_time.end_of_month < Time.now.end_of_month
						errors.add( :base, 'Credit Card has Expired') if errors
						return false
					end

					formatted_expiration = credit_card[:expiration].gsub(/\s*\/\s*/,'')
					formatted_number = credit_card[:card_number].gsub(/\s/,'')

					anet_credit_card = AuthorizeNet::CreditCard.new(
						formatted_number,
						formatted_expiration,
						card_code: credit_card[:card_code],
					)

					anet_payment_profile = AuthorizeNet::CIM::PaymentProfile.new(
						:payment_method		=> anet_credit_card,
						:billing_address	=> anet_billing_address,
					)

					anet_customer_profile = AuthorizeNet::CIM::CustomerProfile.new(
						:email			=> args[:email] || user.try(:email),
						:id				=> user.try(:id),
						:phone			=> billing_address.phone,
						:address		=> anet_billing_address,
						:description	=> "#{anet_billing_address.first_name} #{anet_billing_address.last_name}",
						:ip				=> ip_address,
					)
					anet_customer_profile.payment_profiles = anet_payment_profile


					# create a new customer profile
					response = anet_transaction.create_profile( anet_customer_profile )

					# recover a customer profile if it already exists.
					if response.message_code == ERROR_DUPLICATE_CUSTOMER_PROFILE
						puts response.xml if @enable_debug

						anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )


						profile_id = response.message_text.match( /(\d{4,})/)[1]

						response = anet_transaction.get_profile( profile_id.to_s )

						profile = response.profile
						customer_profile_id = response.profile_id

						# create a new payment profile for existing customer
						anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )
						response = anet_transaction.create_payment_profile( anet_payment_profile, profile )
						puts response.xml if @enable_debug
						customer_payment_profile_id = response.payment_profile_id

						if not( response.success? ) && response.message_code == ERROR_DUPLICATE_CUSTOMER_PAYMENT_PROFILE
							anet_payment_profile.customer_payment_profile_id = customer_payment_profile_id
							anet_transaction = AuthorizeNet::CIM::Transaction.new(@api_login, @api_key, :gateway => @gateway )
							response = anet_transaction.update_payment_profile( anet_payment_profile, profile )
							puts response.xml if @enable_debug

						end


						return { customer_profile_reference: customer_profile_id, customer_payment_profile_reference: customer_payment_profile_id }

					elsif response.success?

						customer_payment_profile_id = response.payment_profile_ids.last

						return { customer_profile_reference: response.profile_id, customer_payment_profile_reference: customer_payment_profile_id }

					else

						puts response.xml if @enable_debug

						NewRelic::Agent.notice_error(Exception.new( "Authorize.net Payment Profile Error: #{response.message_code} - #{response.message_text}"), custom_params: { user_id: user.try(:id) } ) if defined?( NewRelic )

						if response.message_code == ERROR_INVALID_PAYMENT_PROFILE
							errors.add( :base, 'Invalid Payment Information') unless errors.nil?
						else
							errors.add( :base, 'Unable to create customer profile') unless errors.nil?
						end

					end

					return false

				end


			end
		end
	end
end
