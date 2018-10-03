Types::QueryType = GraphQL::ObjectType.define do
  name "Query"
  # Add root-level fields here.
  # They will be entry points for queries on your schema.

  field :pet, Types::PetType do
    description 'Retrieve a pet post by id'

    argument :id, !types.ID, 'The ID of the pet to retrieve'

    resolve ->(obj, args, ctx) {
      Pet.find(args[:id])
    }
  end
  connection :pets, Types::PetType.connection_type do
    resolve -> (obj, args, ctx) {
      Pet.all
    }
  end
end
