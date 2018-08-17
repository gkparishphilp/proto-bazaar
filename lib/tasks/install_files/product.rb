class Product < ApplicationRecord
	include Bazaar::Concerns::ProductConcern

	mounted_at '/store'

	# has_one_attached :cover_attachment
	# has_many_attached :gallery_attachments

end
