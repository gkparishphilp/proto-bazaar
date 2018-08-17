# https://github.com/ptrippett/ups
# https://www.ups.com/upsdeveloperkit/requestaccesskey?loc=en_US
# install 'ups' gem

module Bazaar
	module Services
		module Shipping
			class UPSShippingService < Bazaar::ShippingService

				def initialize( args = {} )

					super( args )

					raise Exception.new('add "gem \'ups\'" to your Gemfile') unless defined?( UPS::Connection )

					@ship_from	= args[:ship_from] || args[:shipper]
					@shipper	= args[:shipper]

					@test_mode = not( Rails.env.production? )
					@test_mode = args[:test_mode] if args.has_key? :test_mode

					@api_key	= args[:api_key] || ENV["UPS_LICENSE_NUMBER"]
					@username	= args[:username] || ENV["UPS_USER_ID"]
					@password	= args[:password] || ENV["UPS_PASSWORD"]

					@server = UPS::Connection.new(test_mode: @test_mode)

					@units = (args[:units] || 'LBS').upcase # KGS || LBS
					@unit_conversion = 1.0
					@unit_conversion = 2.20462 if @units == 'LBS' # KGS to LBS

				end

				def fetch_delivery_status_for_code( code, args = {} )
					return false
				end

				def process( order, args = {} )
					return false
				end

				protected
				def request_address_rates( geo_address, line_items, args = {} )

					default_fields = {
						company_name: '',
						attention_name: '',
						phone_number: '',
					}

					args[:shipper] ||= @shipper
					args[:ship_from] ||= @ship_from

					args[:shipper] = default_fields.merge( args[:shipper] )
					args[:ship_from] = default_fields.merge( args[:ship_from] )


					begin
						response = @server.rates do |rate_builder|

							rate_builder.add_access_request @api_key, @username, @password

							rate_builder.add_shipper args[:shipper]

							rate_builder.add_ship_from args[:ship_from]

							ship_to = default_fields.merge({
								phone_number: geo_address.phone,
								address_line_1: geo_address.street,
								address_line_2: geo_address.street2,
								city: geo_address.city,
								state: geo_address.state_abbrev,
								postal_code: geo_address.zip,
								country: geo_address.geo_country.abbrev
							})
							rate_builder.add_ship_to ship_to

							line_items.each do |line_item|
								# convert from grams to KGs
								package_weight_kgs = (line_item.package_weight * 0.001)

								# rate_builder.add_package weight: package_weight_kgs.to_s, unit: 'KGS'
								rate_builder.add_package weight: (package_weight_kgs * @unit_conversion).to_s, unit: @units
							end
						end

						if response.success?

							rates = response.rated_shipments.collect do |rate|
								{ name: rate[:service_name], code: rate[:service_code], price: (rate[:total].to_f * 100.0).to_i, carrier: 'UPS', currency: 'USD' }
							end

						else

							geo_address.errors.add( :base, :shipping_error, message: 'Not a valid shipping destination.' )
							NewRelic::Agent.notice_error(Exception.new(response.status_code+' > '+response.error_description)) if defined?( NewRelic )
							rates = []

						end

					rescue Exception => e
						raise e if Rails.env.development?
						NewRelic::Agent.notice_error(e) if defined?( NewRelic )
						rates = []
					end

					rates
				end

			end
		end
	end
end
