class Pet < ApplicationRecord
  belongs_to :owner, required: false
  has_many :activities
end