class CreateActivities < ActiveRecord::Migration[5.1]
  def change
    create_table :activities do |t|
      t.text :description
      t.integer :pet_id
      t.integer :owner_id

      t.timestamps
    end
  end
end
