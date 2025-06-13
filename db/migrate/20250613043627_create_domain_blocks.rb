class CreateDomainBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :domain_blocks do |t|
      t.string :actor_id, null: false
      t.string :domain, null: false

      t.timestamps
    end
    
    add_index :domain_blocks, [:actor_id, :domain], unique: true
    add_index :domain_blocks, :domain
    add_foreign_key :domain_blocks, :actors, column: :actor_id
  end
end
