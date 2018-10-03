Types::PetType = GraphQL::ObjectType.define do
  name 'PetType'
  description 'Represents a pet'

  field :id, !types.ID, 'The ID of the pet'
  field :name, types.String, 'The name of the pet'
  field :kind, types.String, 'A type of animal'
  # notice that we could define a custom field and provide a block that will
  # define how to resolve/build this field
  field :capKind, types.String, 'An all caps version of the kind' do
    resolve ->(obj, args, ctx) {
      obj.kind.upcase
    }
  end

  # notice that we could map active record relation

  field :owner, -> { Types::OwnerType } do
    resolve -> (obj, args, ctx) {
      RecordLoader.for(Owner).load(obj.owner_id)
    }
  end
  connection :activities, Types::ActivityType.connection_type do
    resolve -> (obj, args, ctx) {
      OneToManyLoader.for(Activity, :pet_id).load(obj.id)
    }
  end


end