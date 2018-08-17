module Bazaar
	module Concerns

		module CheckoutControllerConcern
			extend ActiveSupport::Concern

			included do
				include SwellId::Concerns::PermissionConcern

				before_action :get_checkout_services, only: [:new, :create]
				before_action :get_order, only: [:show]

				helper_method	:checkout_options
				helper_method	:discount_options
				helper_method	:shipping_options
				helper_method	:tax_options
			end


			####################################################
			# Class Methods

			module ClassMethods




			end


			####################################################
			# Instance Methods

			protected

				def verify_signature!( order, options={} )
					verified_message = Rails.application.message_verifier('order.id').verify(params[:signature])

					raise ActionController::RoutingError.new( 'Not Found' ) unless verified_message[:id] == @order.id && verified_message[:code] == @order.code && verified_message[:expiration].to_s == params[:t] && request.original_url.split('?').first == verified_message[:url]
					if Time.now.to_i > params[:t].to_i
						set_flash 'Login to view your orders'
						redirect_to '/login'
						return false
					end
				end

				def checkout_options
					{
						discount: discount_options,
						shipping: shipping_options,
						tax: tax_options,
					}
				end

				def discount_options
					# @todo
					{}
				end

				def get_checkout_services
					@order_service			= ApplicationOrderService.new
					@fraud_service			= @order_service.fraud_service
				end

				def get_order
					@order = Bazaar::Order.find_by( code: params[:id] )
					raise ActionController::RoutingError.new( 'Not Found' ) unless @order.present?
				end

				def signed_checkout_path( @order )
					expiration = 30.minutes.from_now.to_i
					checkout_path( @order.code, format: :html, expiration: expiration, signature: Rails.application.message_verifier('order.id').generate( url: checkout_path( @order.code ), code: @order.code, id: @order.id, expiration: expiration ) )
				end

				def order_attributes
					# @todo
				end


				def order_success!

					@cart.update( order: @order, status: 'success' )

					log_event( user: @order.user, name: 'purchase', value: @order.total, on: @order, content: "placed an order for $#{@order.total/100.to_f}." )

				end

				def shipping_options
					# @todo
					{}
				end

				def tax_options
					# @todo
					{}
				end


		end

	end
end
