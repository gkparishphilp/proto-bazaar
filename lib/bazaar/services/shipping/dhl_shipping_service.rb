require 'rest-client'

module Bazaar
	module Services
		module Shipping
			class DHLShippingService < Bazaar::ShippingService

				# https://api.dhlglobalmail.com/docs/v1/track.html
				JSON_TRACKING_ENDPOINT = 'https://api.dhlglobalmail.com/v1/mailitems/track'

				def initialize( args = {} )
					super( args )

					warehouse_address = args[:warehouse] || Bazaar.warehouse_address

					@access_token	= args[:access_token]
					@username		= args[:username]
					@password		= args[:password]
					@client_id		= args[:client_id]

				end

				def fetch_delivery_status_for_code( code, args = {} )

					options = { number: code, access_token: @access_token, client_id: @client_id }

					raw_result = RestClient.get JSON_TRACKING_ENDPOINT, {content_type: :json, accept: :json, params: options }
					result = JSON.parse( raw_result, symbolize_names: true )
					mail_item = result[:data][:mailItems].first

					status = {
						status: nil,
						tracking_number: code,
						events: [],
						scheduled_delivered_at: nil,
						delivered_at: nil,
						shipped_at: nil,
						carrier_name: 'DHL Ecommerce',
					}

					mail_item[:events].each do |event|
						time = Time.parse("#{event[:date]} #{event[:time]} #{event[:timeZone]}")

						status[:events] << { name: event[:description], location: event[:location], country: event[:country], time: time, message: event[:secondaryEventDesc] }
						puts "#{event.name} at #{event.location.city}, #{event.location.state} on #{event.time}. #{event.message}"
						status[:delivered_at] = time if event[:description].downcase.include?( 'delivered' )
						status[:shipped_at] = [ (status[:shipped_at] || time), time ].min

					end

					status[:status] = :delivered if status[:delivered_at]

					status
				end

			end
		end
	end
end
