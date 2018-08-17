class ProductsController < ApplicationController
	include Bazaar::Concerns::ProductsControllerConcern

	def index
		@products = Product.published.order( title: :asc ).page(params[:page]).per(10)
	end

	def show
		@product = Product.friendly.find params[:id]
	end

end
