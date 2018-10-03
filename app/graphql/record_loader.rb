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