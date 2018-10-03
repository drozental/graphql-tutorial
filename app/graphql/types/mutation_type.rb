Types::MutationType = GraphQL::ObjectType.define do
  name "Mutation"

  field :createPet, Types::PetType do
    description 'Allows you to create a new pet'

    argument :name, !types.String
    argument :kind, !types.String

    resolve ->(obj, args, ctx) {
      pet = Pet.new(args.to_h)

      pet.save

      pet
    }
  end
end