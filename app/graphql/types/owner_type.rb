Types::OwnerType = GraphQL::ObjectType.define do
  name 'OwnerType'
  description 'Represents a owner model'

  field :id, types.ID, 'The unique ID of the owner'
  field :firstName, types.String, 'The first name of the owner', property: :first_name # notice that we use property to map active record field to the graphql field
  field :lastName, types.String, 'The last name of the owner', property: :last_name
  field :bio, types.String, 'A bio for the owner giving some details about them'
  # field :activities, types[Types::ActivityType]
  # field :pets, types[Types::PetType]

  field :pets, -> { types[Types::PetType] }  do
    resolve -> (obj, args, ctx) {
      OneToManyLoader.for(Pet, :owner_id).load(obj.id)
    }
  end

  field :activities, -> { types[Types::ActivityType] } do
    resolve -> (obj, args, ctx) do
      OneToManyLoader.for(Activity, :owner_id).load(obj.id)
    end
  end
end

