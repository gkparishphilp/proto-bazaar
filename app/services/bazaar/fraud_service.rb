module Bazaar
	module FraudService

    def initialize( options = {} )
      @options = options
    end

    def fraud?( order )
      return false
    end

    def suspicious?( order )
      return false
    end

    def accept_review( order )
      return false unless order.review?

			order.active!

			order.order_items.where.not( subscription: nil ).each do |order_item|
				order_item.subscription.active! if order_item.subscription.review?
			end

			order.order_items.prod.where( item_type: SwellEcom::Subscription.base_class.name ).each do |order_item|
				order_item.item.active! if order_item.item.review?
			end


      return true
    end

    def mark_for_review( order )

			order.review!

			order.order_items.prod.where.not( subscription: nil ).each do |order_item|
				order_item.subscription.review! if order_item.subscription.active?
			end

    end

    def reject_review( order )
      return false unless order.review?

      order.rejected!

      order.order_items.where.not( subscription: nil ).each do |order_item|
        order_item.subscription.rejected!
      end

      order.order_items.prod.where( item_type: SwellEcom::Subscription.base_class.name ).each do |order_item|
        order_item.item.rejected!
      end

      return true

    end

    def validate( order )
      order.errors.add( :base, :processing_error, message: 'We are unable to process your order, please contact support for assistance.' ) if self.fraud?( order )
    end

	end
end
