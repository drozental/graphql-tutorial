Types::ActivityType = GraphQL::ObjectType.define do
  name 'ActivityType'
  description 'Represents a activity for owner and a pet'

  field :id, types.ID, 'The ID of the activity'
  field :description, types.String, 'The name for the activity'


  field :owner, -> { Types::OwnerType } do
    resolve -> (obj, args, ctx) do
      RecordLoader.for(Owner).load(obj.owner_id)
    end
  end
  field :pet, -> { Types::PetType } do
    resolve -> (obj, args, ctx) do
      RecordLoader.for(Pet).load(obj.pet_id)
    end
  end
end