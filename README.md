"The strongly typed GraphQL data querying language is a revolutionary new way to interact with your server. Similar to how JSON very quickly overtook XML, GraphQL will likely take over REST. Why? Because GraphQL allows us to express our data in the exact same way we think about it."
# Let's build our first GraphQL
1. Define our tables
```
rails generate model Pet name:text kind:text owner_id:integer
rails generate model Owner first_name:text last_name:text bio:text
rails generate model Activity decription:text pet_id:integer owner_id:integer
```
2. Migrate them
```
rails db:create && rails db:migrate
```
3. Add relationships to models
``` ruby
class Activity < ApplicationRecord
  belongs_to :owner
  belongs_to :pet
end

class Pet < ApplicationRecord
  belongs_to :owner, required: false
  has_many :activities
end

class Owner < ApplicationRecord
  has_many :activities
  has_many :pets
end

```
4. Add graphql and faker gem and install it. Generate graphql structure
```ruby
# Gemfile

gem 'graphql'
gem 'graphiql-rails', group: :development
gem 'faker', group: :development

$ bundle install
$ rails generate graphql:install
$ rails c
```

```ruby
  10.times { Pet.create(name: Faker::Dog.name, kind: Faker::Dog.breed) }
  10.times { Owner.create(first_name: Faker::Name.first_name, last_name: Faker::Name.last_name, bio: Faker::Lorem.paragraph) }
  
  owners = Owner.all
  
  Pet.all.each do |pet|
    owner = owners.sample
    pet.update(owner: owner)
  
    5.times { Activity.create(decription: Faker::Seinfeld.quote, owner: owner, pet: pet) }
  end
```
5. Let's define our types!
```ruby
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

Types::ActivityType = GraphQL::ObjectType.define do
  name 'ActivityType'
  description 'Represents a activity for owner and a pet'

  field :id, types.ID, 'The ID of the activity'
  field :decription, types.String, 'The name for the activity'
  field :owner, Types::OwnerType, 'The owner who participated in the activity'
  field :pet, Types::PetType, 'The pet that the activity was performed for'
end

Types::PetType = GraphQL::ObjectType.define do
  name 'PetType'
  description 'Represents a pet'

  field :id, !types.ID, 'The ID of the pet'
  field :name, types.String, 'The name of the pet'
  field :kind, types.String, 'A type of animal'
  # notcie that we could define a custom field and provide a block that will 
  # need to define on how to resolve/build this field
  field :capKind, types.String, 'An all caps version of the kind' do
    resolve ->(obj, args, ctx) {
      obj.kind.upcase
    }
  end
  
  # notice that we could map active record relations 
  field :owner, Types::OwnerType, 'The owner of the pet'
  field :activities, types[Types::ActivityType]
end
```
6. Let's start graphiQL!! Wait, what is it?
It is a tool to query your new endpoint/s and it comes with graphql out of the box when doing ...
yes :( full rails. It is not available with rails api.
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
      decription
    }
  }
}

```
7. That's great!!! But what about the rest of the CRUD ops? MUTATIONS: 
queries that have consequences
```ruby
Types::MutationType = GraphQL::ObjectType.define do
  name "Mutation"

  field :createPet, Types::PetType do
    description 'Allows you to create a new pet'

    argument :name, !types.String
    argument :kind, !types.String

    resolve ->(obj, args, ctx) {
      post = Pet.new(args.to_h)

      post.save

      post
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
Can we now build update and delete mutations ourselves?
8. What about performance?  Does listing pets and related result in N+1 number of queries?
How many queries does execute now?
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
      decription
    }
  }
}
```
* graphql-batch gem
* batch-loader gem 
* Using .includes on your ActiveRecord database calls to preload all associations (naive approach).
Let's try graphql-batch gem.
Add it to our Gemfile and run bundle install
```ruby
gem 'graphql-batch'
```
9. We will now create two custom loaders: let's take a look
 ```ruby
# create this class in graphql folder
# this will take foreign key from each one of our records
# and retrieve it from the provided model
class RecordLoader < GraphQL::Batch::Loader
  def initialize(model)
    @model = model
  end

  def perform(ids)
    @model.where(id: ids).each { |record| fulfill(record.id, record) }
    ids.each { |id| fulfill(id, nil) unless fulfilled?(id) }
  end
end

# this will take the related model and the foreign key to the current
# object and will batch all of the selects for us
# could this be written even simpler?
class ForeignKeyLoader < GraphQL::Batch::Loader
  def initialize(model, foreign_key)
    @model = model
    @foreign_key = foreign_key
  end

  def perform(foreign_value_sets)
    foreign_values = foreign_value_sets.flatten.uniq
    records = @model.where(@foreign_key => foreign_values).to_a

    foreign_value_sets.each do |foreign_value_set|
      matching_records = records.select { |r| foreign_value_set.include?(r.send(@foreign_key)) }
      fulfill(foreign_value_set, matching_records)
    end
  end
end
```
10. Update our schema to use graphql-batch
```ruby
# add to our schema definition
use GraphQL::Batch
```
11. Let's now update our type definitions to resolve model relationships
with the new resolve definitions
```ruby
# in Pet type replace the relationships with the below
field :owner, -> { Types::OwnerType } do
  resolve -> (obj, args, ctx) {
    RecordLoader.for(Owner).load(obj.owner_id)
  }
end
field :activities, -> { types[Types::ActivityType] }  do
  resolve -> (obj, args, ctx) {
    ForeignKeyLoader.for(Activity, :pet_id).load([obj.id])
  }
end
```
Can you now update owner type and pet relationship?
How many queries should this run now?  
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
      decription
    }
  }
}
```
12. What about pagination?  As data sets grow, will not having pagination have a negative impact on performance?
13. What about these? Not ruby, but great for rapid development? Pros/Cons?
  * http://www.graph.cool/
  * https://www.prismagraphql.com/
  * https://github.com/postgraphql/postgraphql

 
# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
