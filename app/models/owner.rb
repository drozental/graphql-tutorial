class Owner < ApplicationRecord
  has_many :activities
  has_many :pets
end