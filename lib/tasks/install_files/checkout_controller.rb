class CheckoutController
	include Bazaar::Concerns::CheckoutControllerConcern

	def new
		redirect_to '/' if @cart.blank? || @cart.success?
		@order = CheckoutOrder.new order_attributes

		@order_service.calculate( @order, checkout_options )

	end

	def create
		redirect_to '/' if @cart.blank? || @cart.success?

		@order = CheckoutOrder.new order_attributes
		@order_service.validate( @order, checkout_options )
		@order_service.process( @order, checkout_options ) if not( @order.has_errors? )

		if not( @order.has_errors? )
			order_success!

			# CheckoutPostProcessingWorker.perform_async( order.id )
			# OR
			@order_service.post_processing( @order )
			@fraud_service.mark_for_review( @order ) if @fraud_service.suspicious?( @order )
			@agreement_service.process( order )
			OrderMailer.receipt( @order ).deliver_now

			redirect_to signed_checkout_path( @order )

		else

			render :new

		end

	end

	def show
		if current_user != @order.user
			if params[:signature].present?
				verify_signature!
			else
				authorize( @order )
			end
		end
	end

end
