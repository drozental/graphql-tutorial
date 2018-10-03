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