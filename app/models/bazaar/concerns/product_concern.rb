module Bazaar
	module Concerns

		module ProductConcern
			extend ActiveSupport::Concern

			included do

				include Pulitzer::Concerns::URLConcern
				include FriendlyId

				has_one_attached :avatar_attachment

				friendly_id :slugger, use: [ :slugged, :history ]

				acts_as_taggable_array_on :tags

				before_save :set_avatar

			end


			####################################################
			# Class Methods

			module ClassMethods




			end


			####################################################
			# Instance Methods

			protected

				def set_avatar
					if self.avatar_attachment.attached?
						self.avatar = self.avatar_attachment.service_url
					else
						self.avatar = "https://gravatar.com/avatar/" + Digest::MD5.hexdigest( self.email ) + "?d=retro&s=200"
					end

				end

				def slugger
					if self.slug_pref.present?
						self.slug = nil # friendly_id 5.0 only updates slug if slug field is nil
						return self.slug_pref
					else
						return self.title
					end
				end
		end

	end
end
