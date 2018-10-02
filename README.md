# Let's build our first GraphQL API in RoR
GraphQL is taking the world by storm... well, maybe.  The adoption of GraphQL seems
 to be increasing and that means we should be aware of it and understand it. 
It naturally seems to be a good fit for RoR APIs,
 as these two technologies would be used in similar cases: 
 POC's and rapid development situations
 
 In this article, we'll accomplish the following things:
 * Create a Rails App
 * Define our simple DB schema
 * Define our simple GraphQL schema, types, queries and mutations
 * Optimise our API's to avoid N+1 queries
 * Add pagination to the API's

## Creating our Rails App and defining DB schema
Note: There is a new version of the graphql.  Version 1.8 has a slightly different  syntax and folder structure.
 
Versions: 
* ruby -v 2.4.1
* graphql -v 1.7.14
* rails -v 5.1.4
1. Create a rails app with the below command.  Use your own name instead of APP_NAME
```ruby
rails new APP_NAME
```
2. Lets define our tables with `rails g model` commands
```
rails generate model Pet name:text kind:text owner_id:integer
rails generate model Owner first_name:text last_name:text bio:text
rails generate model Activity description:text pet_id:integer owner_id:integer
```
3. It is time to run the generated migrations
```
rails db:create && rails db:migrate
```
4. The tables and models have been generated.  We will now add relationships to our models
``` ruby
# activity.rb
class Activity < ApplicationRecord
  belongs_to :owner
  belongs_to :pet
end

# pet.rb
class Pet < ApplicationRecord
  belongs_to :owner, required: false
  has_many :activities
end

# owner.rb
class Owner < ApplicationRecord
  has_many :activities
  has_many :pets
end
```
5. Now that our db schema and models are defined, let's add some data to the app

Add faker gem to the Gemfile:
```ruby
gem 'faker', group: :development
```
And then install it by running 
```bash
bundle install
```

Once it is installed, start your rails console
```bash
rails c
```
In the console, let's populate our models with some data
```ruby
  15.times { Pet.create(name: Faker::Dog.name, kind: Faker::Dog.breed) }
  15.times { Owner.create(first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, bio: Faker::Lorem.paragraph) }
  
  owners = Owner.all
  
  Pet.all.each do |pet|
    owner = owners.sample
    pet.update(owner: owner)
  
    5.times { Activity.create(description: Faker::Seinfeld.quote, owner: owner, pet: pet) }
  end
```

## Define our simple GraphQL schema, types, queries and mutations
1. It is now time to add graphql to our app. In the `Gemfile` add graphql dependency
```ruby
# Gemfile

gem 'graphql', '1.7.14'
```
Once the dependency has been added to the Gemfile, let's install the gem and initialize it in our project 
```bash
$ bundle install
$ rails generate graphql:install
```
This will create the "conventional" folder structure and add a default type and schema that we'll need to define ourselves

2. Now it is time to define our graphQL types.  There is a types folder under graphql, that holds our types.  Let's add our 3 types
```ruby
# in ./graphql/types/pet_type.rb file
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
  
  # notice that we could map active record relations 
  field :owner, Types::OwnerType, 'The owner of the pet'
  field :activities, types[Types::ActivityType]
end

# in ./graphql/types/owner_type.rb
Types::OwnerType = GraphQL::ObjectType.define do
  name 'OwnerType'
  description 'Represents a owner model'

  field :id, types.ID, 'The unique ID of the owner'
  field :firstName, types.String, 'The first name of the owner', property: :first_name # notice that we use property to map active record field to the graphql field
  field :lastName, types.String, 'The last name of the owner', property: :last_name
  field :bio, types.String, 'A bio for the owner giving some details about them'
  field :activities, types[Types::ActivityType]
  field :pets, types[Types::PetType]
end

#in ./graphql/types/activity_type.rb
Types::ActivityType = GraphQL::ObjectType.define do
  name 'ActivityType'
  description 'Represents a activity for owner and a pet'

  field :id, types.ID, 'The ID of the activity'
  field :description, types.String, 'The name for the activity'
  field :owner, Types::OwnerType, 'The owner who participated in the activity'
  field :pet, Types::PetType, 'The pet that the activity was performed for'
end
```
3. Let's deinfe couple of queries
```ruby
# ./graphql/type/query_type.rb
field :pet, Types::PetType do
  description 'Retrieve a pet post by id'

  argument :id, !types.ID, 'The ID of the pet to retrieve'

  resolve ->(obj, args, ctx) {
    Pet.find(args[:id])
  }
end

field :pets, types[Types::PetType] do
  description 'Retrieve a list of all pets'

  resolve ->(obj, args, ctx) {
    Pet.all
  }
end

```
4. Let's start graphiQL!! Wait, what is it?
It is a graphic tool to query your new endpoint/s and it comes with graphql ruby gem out of the box when using with ...
yes, full rails. It is not available with rails api.  To start it, just start your rails app!
```ruby
rails serve
```
Navigate to ` localhost:3000/graphiql`
Experiment with the query or run the below query:
```ruby
{
  pet(id: 1) {
    name
    kind
    capKind
    owner {
      lastName
      firstName
    }
  }
  pets {
    id
    name
    owner {
      lastName
      firstName
      bio
      pets {
        name
        kind
      }
    }
    activities {
      description
    }
  }
}

```
4. That's great!!! But what about the rest of the CRUD ops? In graphQL, we use MUTATIONS: 
queries that have consequences.  Let's create a `create pet` mutation.
```ruby
# ./graphql/types/mutation_type.rb
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
```
Try out a create pet query(reload your localhost page and the code complete should pop up)
```ruby
mutation {
  createPet(name: "Raisin", kind: "Frenchie") {
    id
    name
    kind
  }
}
```
Try adding update and delete mutations on your own?

## Optimise our API's to avoid N+1 queries
How does graphql api perform at the moment?  Does listing pets and related objects result in N+1 number of queries?
Look in the terminal where you've started rails to see what and how many queries are run for the below query?
```ruby
{
  pets {
    id
    name
    owner {
      lastName
      firstName
      bio
      pets {
        name
        kind
      }
    }
    activities {
      description
    }
  }
}
```
Yes, the results are not so great.  How could we deal with this?  There are couple solutions and today will look at the `garphql-batch`
Couple of more options to consider: 
* batch-loader gem 
* Using .includes in ActiveRecord

1. graphql-batch gem

Add it to our Gemfile and run bundle install
```ruby
gem 'graphql-batch'
```
2. We will now create two custom loaders: let's take a look
 ```ruby
# in ./graphql/record_loader.rb
# this class will take foreign keys for all of our records
# and retrieve it from the provided model in one call to the db
class RecordLoader < GraphQL::Batch::Loader
  def initialize(model)
    @model = model
  end

  def perform(ids)
    @model.where(id: ids).each { |record| fulfill(record.id, record) }
    ids.each { |id| fulfill(id, nil) unless fulfilled?(id) }
  end
end

# in ./graphql/one_to_many_loader
# this will take the related model and the foreign key to the current
# object and will batch all of the selects for us
# could this be written even simpler?
class OneToManyLoader < GraphQL::Batch::Loader
  def initialize(model, foreign_key)
    @model = model
    @foreign_key = foreign_key
  end

  def perform(ids)
    all_records = @model.where(@foreign_key => ids).to_a

    # this is for a one to many relationship batch processing
    # we want to fulfill every foreign key with an array of matched records
    ids.each do |id|
      matches = all_records.select{ |r| id == r.send(@foreign_key) }
      fulfill(id, matches)
    end
  end
end
```
3. Now we need to update our schema to use graphql-batch
```ruby
# ./graphql/APP_NAME_schema.rb
use GraphQL::Batch
```
4. Let's now update our type definitions to resolve model relationships
with the new resolve definitions
```ruby
# ./graphql/pet_type.rb
# in Pet type replace the relationships with the below
field :owner, -> { Types::OwnerType } do
  resolve -> (obj, args, ctx) {
    RecordLoader.for(Owner).load(obj.owner_id)
  }
end
field :activities, -> { types[Types::ActivityType] }  do
  resolve -> (obj, args, ctx) {
    OneToManyLoader.for(Activity, :pet_id).load(obj.id)
  }
end

# ./graphql/owner_type.rb
field :pets, -> { types[Types::PetType] }  do
  resolve -> (obj, args, ctx) {
    OneToManyLoader.for(Pet, :owner_id).load(obj.id)
  }
end

# ./graphql/activity_type.rb
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
```
5. Let's check how many queries will run with our new batc loaders?  
```ruby
{
  pets {
    id
    name
    owner {
      lastName
      firstName
      bio
      pets {
        name
        kind
      }
    }
    activities {
      description
    }
  }
}
```
We are now down to four database queries, which is a great improvement. 

## Add pagination to the API's
1. What about pagination?  As data sets grow, will not having pagination have a negative impact on performance?

Here is the spec: https://facebook.github.io/relay/graphql/connections.htm

The spec calls for last, first and after.  When providing `last` and `first`, that is the number of records to take from either the begining or the end of the result set.  `After` specifies the offset.

The default schema for pagination looks something like below.  `pageInfo` provides some info about navigation.
`edges` provides the data in the `node` elements.  That is where we put our usual query. 
```ruby
  pageInfo {
    startCursor
    endCursor
    hasNextPage
    hasPreviousPage
  }
  edges {
    cursor
    node {
      
    }
  }
```
2. We could add pagination two our query and we could also add pagination to the related entities in our query. 
We are going to accomplish all of that by using connections.  Connections comes with pagination out of the box.  Let's give that a try.
```ruby
# ./graphql/types/query_type.rb
# we update from field to connection and define new return type of
# Types::PetType.connection_type
connection :pets, Types::PetType.connection_type do
  resolve -> (obj, args, ctx) {
    Pet.all
  }
end
```
That's all!  Let's play around with it now:
```ruby
    {
      pets(last: 4) {
        pageInfo {
          startCursor
          endCursor
          hasNextPage
          hasPreviousPage
        }
        edges {
          cursor
          node {
            id
            name
            owner {
              lastName
              firstName
              bio
              pets {
                name
                kind
              }
            }
            activities {
              id
              description 
            }
          }
        }
      }
    }
```

What about paginating one to many relationships like our `activities`?  Wouldn't it be nice to only show the first 2 and then show more if user requests it?

We could do that as well.  Add a connection to our pet_type.rb:
```ruby
connection :activities, Types::ActivityType.connection_type do
  resolve -> (obj, args, ctx) {
    OneToManyLoader.for(Activity, :pet_id).load([obj.id])
  }
end
```
Now we need to change our query, because `activies` returns a paginated object and not a plain `Types::ActivityType`
```ruby
{
pets(last: 4) {
    pageInfo {
      startCursor
      endCursor
      hasNextPage
      hasPreviousPage
    }
    edges {
      cursor
      node {
        id
        name
        owner {
          lastName
          firstName
          bio
          pets {
            name
            kind
          }
        }
        activities(first: 2) {
          edges {
            node {
              id
              decription 
            }
          }
        }
      }
    }
  }
}
```

## Further considerations
Resources: 
* http://graphql-ruby.org/guides
* https://graphql.org/learn/

Noteworthy: 
  * http://www.graph.cool/
  * https://www.prismagraphql.com/
  * https://github.com/postgraphql/postgraphql