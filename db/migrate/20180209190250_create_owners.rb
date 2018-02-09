class CreateOwners < ActiveRecord::Migration[5.1]
  def change
    create_table :owners do |t|
      t.text :first_name
      t.text :last_name
      t.text :bio

      t.timestamps
    end
  end
end
