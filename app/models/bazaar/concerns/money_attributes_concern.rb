module Bazaar
	module Concerns

		module MoneyAttributesConcern
			extend ActiveSupport::Concern

			included do
			end


			####################################################
			# Class Methods

			module ClassMethods

				def money_attributes( *money_attribute_names )
					money_attribute_names = [money_attribute_names] unless money_attribute_names.is_a? Array

					money_attribute_names.each do |money_attribute_name|

						define_method "#{money_attribute_name}_as_money" do
							if self.try(money_attribute_name).nil?
								nil
							else
								self.try(money_attribute_name) / 100.0
							end
						end

						define_method "#{money_attribute_name}_as_money=" do |decimal_value|
							if decimal_value.nil?
								self.try("#{money_attribute_name}=", nil )
							else
								self.try("#{money_attribute_name}=", (decimal_value.to_f * 100.0).round )
							end
						end

						define_method "#{money_attribute_name}_as_money_string" do
							if self.try(money_attribute_name).nil?
								nil
							else
								ActionController::Base.helpers.number_to_currency( self.try(money_attribute_name) / 100.0, unit: '' )
							end
						end

						define_method "#{money_attribute_name}_as_money_string=" do |decimal_value|
							if decimal_value.nil?
								self.try("#{money_attribute_name}=", nil )
							else
								self.try("#{money_attribute_name}=", (decimal_value.to_f * 100.0).round )
							end
						end

						define_method "#{money_attribute_name}_formatted" do
							if self.try(money_attribute_name).nil?
								nil
							else
								ActionController::Base.helpers.number_to_currency( self.try(money_attribute_name) / 100.0 )
							end
						end

					end
				end

				#def mounted_at
				#	return @@mounted_at
				#end

			end

		end

	end
end
