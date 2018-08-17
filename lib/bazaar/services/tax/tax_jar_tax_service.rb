require 'taxjar'

module Bazaar
	module Services
		module Tax
			class TaxJarTaxService < Bazaar::TaxService

				def initialize( args = {} )
					raise Exception.new('add "gem \'taxjar-ruby\'" to your Gemfile and "require \'taxjar\'" at the top of config/initializers/swell_ecom.rb') unless defined?( Taxjar )

					@environment = args[:environment].to_sym if args[:environment].present?
					@environment ||= :production if Rails.env.production?
					@environment ||= :development

					@client = Taxjar::Client.new(
						api_key: args[:api_key] || ENV['TAX_JAR_API_KEY']
					)

					@warehouse_address = args[:warehouse] || Bazaar.warehouse_address
					@origin_address = args[:origin] || Bazaar.origin_address

					@nexus_addresses = args[:nexus] || []
					unless @nexus_addresses.present?
						Bazaar.nexus_addresses.each do |address|
							@nexus_addresses << {
								:address_id => address[:address_id],
								:country => address[:country],
								:zip => address[:zip],
								:state => address[:state],
								:city => address[:city],
								:street => address[:street]
							}
						end
					end


				end

				def calculate( obj, args = {} )

					return self.calculate_order( obj ) if obj.is_a? Order
					return self.calculate_cart( obj ) if obj.is_a? Cart

				end

				def process( order, args = {} )
					return true unless @environment == :production
					order_info = get_order_info( order )

					order_info[:sales_tax] = order.order_items.select{|order_item| order_item.tax? }.sum(&:subtotal).to_f / 100.0
					tax_for_order = @client.tax_for_order( order_info )

					tax_breakdown = tax_for_order.breakdown
					if tax_breakdown.present? && ( line_items = tax_breakdown.line_items.to_a ).present?
						order_info[:line_items].each do |order_info_line_item|
							tax_line_item = line_items.first
							line_items.delete(tax_line_item)

							order_info_line_item[:sales_tax] = tax_line_item.tax_collectable
						end
					end

					begin

						if ( tax_jar_order = @client.show_order( order.code, from_transaction_date: order.created_at.strftime('%Y/%m/%d'), to_transaction_date: order.created_at.strftime('%Y/%m/%d') ) ).present?

							tax_jar_order = @client.update_order( order_info )

						end

					rescue Taxjar::Error::NotFound => e

						begin

							tax_jar_order = @client.create_order( order_info )

						rescue Exception => e

							NewRelic::Agent.notice_error(e) if defined?( NewRelic )
							puts e

							return false

						end

					end

					# @todo process refunds
					# order.transactions.negative.each do |refund_transaction|
					# 	refund_info = order_info.merge(
					# 		transaction_id: "refund-#{refund_transaction.id}",
					# 		transaction_date: order.created_at.strftime('%Y/%m/%d'),
					# 		amount: ...
					# 	)
					# end

					tax_jar_order
				end

				protected

				def calculate_cart( cart )
					# don't know shipping address, so can't calculate
				end

				def calculate_order( order )
					order.tax = 0
					return false if not( order.billing_address.validate ) || order.billing_address.geo_country.blank? || order.billing_address.zip.blank?
					return false if order.billing_address.geo_country.abbrev == 'US' && order.billing_address.geo_state.blank?

					order_info = get_order_info( order )

					begin
						tax_for_order = @client.tax_for_order( order_info )
					rescue Taxjar::Error::NotFound => ex

						NewRelic::Agent.notice_error(ex) if defined?( NewRelic )
						puts ex
						order.billing_address.errors.add :base, :invalid, message: "address is invalid"

					rescue Taxjar::Error::BadRequest => ex

						if ex.message.include?( 'isn\'t a valid postal code' )
							order.billing_address.errors.add :zip, :invalid, message: "#{order_info[:to_zip]} is not a valid zip/postal code"
							return order
						elsif ex.message.include?( 'is not used within to_state' )
							order.billing_address.errors.add :zip, :invalid, message: "#{order_info[:to_zip]} is not a valid zip/postal code within #{order_info[:to_state]}"
							return order
						else
							NewRelic::Agent.notice_error(ex) if defined?( NewRelic )
							puts ex
							order.billing_address.errors.add :base, :invalid, message: "address is invalid"
							return false
						end

					end
					tax_breakdown = tax_for_order.breakdown
					tax_geo = nil

					unless tax_breakdown.present?
						# puts JSON.pretty_generate order_info
						# puts JSON.pretty_generate JSON.parse( tax_for_order.to_json )
						return order
					end


					if tax_for_order.tax_source == 'destination'
						tax_geo = { country: order_info[:from_country], state: order_info[:from_state], city: order_info[:from_city] }
					elsif tax_for_order.tax_source == 'origin'
						tax_geo = { country: order_info[:from_country], state: order_info[:from_state], city: order_info[:from_city] }
					end

					tax_order_item = order.order_items.new( subtotal: (tax_for_order.amount_to_collect * 100).to_i, title: "Tax", order_item_type: 'tax' )


					if not( tax_breakdown.country_tax_collectable.nil? ) && tax_breakdown.country_tax_collectable.abs > 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'country_tax_collectable' => (tax_breakdown.country_tax_collectable * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Tax (#{tax_geo[:country]}) #{tax_breakdown.country_tax_collectable}"
					end

					if not( tax_breakdown.county_tax_collectable.nil? ) && tax_breakdown.county_tax_collectable.abs > 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'county_tax_collectable' => (tax_breakdown.county_tax_collectable * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Tax (county) #{tax_breakdown.county_tax_collectable}"
					end

					if not( tax_breakdown.state_tax_collectable.nil? ) && tax_breakdown.state_tax_collectable.abs > 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'state_tax_collectable' => (tax_breakdown.state_tax_collectable * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Tax (#{tax_geo[:state]}) #{tax_breakdown.state_tax_collectable}"
					end

					if not( tax_breakdown.city_tax_collectable.nil? ) && tax_breakdown.city_tax_collectable.abs > 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'city_tax_collectable' => (tax_breakdown.city_tax_collectable * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Tax (#{tax_geo[:city]}) #{tax_breakdown.city_tax_collectable}"
					end

					if not( tax_breakdown.special_district_tax_collectable.nil? ) && tax_breakdown.special_district_tax_collectable.abs > 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'special_district_tax_collectable' => (tax_breakdown.special_district_tax_collectable * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Taxes (district) #{tax_breakdown.special_district_tax_collectable}"
					end

					if tax_breakdown.gst.present? && tax_breakdown.gst != 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'gst' => (tax_breakdown.gst * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Tax (GST) #{tax_breakdown.gst}"
					end

					if tax_breakdown.pst.present? && tax_breakdown.pst != 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'pst' => (tax_breakdown.pst * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Tax (PST) #{tax_breakdown.pst}"
					end

					if tax_breakdown.qst.present? && tax_breakdown.qst != 0.0
						tax_order_item.properties = tax_order_item.properties.merge( 'qst' => (tax_breakdown.qst * 100).to_i ) if tax_order_item.respond_to?( :properties )
						# puts "Tax (QST) #{tax_breakdown.qst}"
					end

					# puts JSON.pretty_generate tax_order_item.properties if tax_order_item.respond_to?( :properties )
					order.tax = tax_order_item.subtotal


					return order

				end

				def get_order_info( order )

					shipping_amount = order.order_items.select{ |order_item| order_item.shipping? }.sum(&:subtotal) / 100.0
					order_total = order.order_items.select{ |order_item| order_item.prod? }.sum(&:subtotal) / 100.0
					discount_total = order.order_items.select{ |order_item| order_item.discount? }.sum(&:subtotal) / 100.0

					discount_applied = 0
					line_items = []
					order.order_items.each do |order_item|
						if order_item.prod?
							discount = [ -(discount_total - discount_applied), order_item.subtotal ].min

							line_items << {
								:quantity => order_item.quantity,
								:unit_price => (order_item.price / 100.0),
								:product_tax_code => order_item.tax_code,
								:product_identifier => order_item.sku,
								:description => order_item.title,
								:discount => discount,
							}

							discount_applied = discount_applied - discount
						end
					end

					order_info = {
					    :to_country => order.shipping_address.geo_country.try(:abbrev),
					    :to_zip => order.shipping_address.zip,
					    :to_city => order.shipping_address.city,
					    :to_state => order.shipping_address.state_abbrev,
					    :from_country => @warehouse_address[:country] || @origin_address[:country],
					    :from_zip => @warehouse_address[:zip] || @origin_address[:zip],
					    :from_city => @warehouse_address[:city] || @origin_address[:city],
					    :from_state => @warehouse_address[:state] || @origin_address[:state],
					    :amount => order_total + shipping_amount + discount_total,
					    :shipping => shipping_amount,
					    :nexus_addresses => @nexus_addresses,
					    :line_items => line_items,
					}

					order_info[:transaction_id] = order.code if order.code.present?
					order_info[:transaction_date] = order.created_at.strftime('%Y/%m/%d') if order.created_at.present?

					order_info

				end

			end
		end
	end
end
