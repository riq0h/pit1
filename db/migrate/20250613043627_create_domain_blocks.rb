class CreateDomainBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :domain_blocks do |t|
      t.references :actor, null: false, foreign_key: true
      t.string :domain, null: false

      t.timestamps
    end
    
    add_index :domain_blocks, [:actor_id, :domain], unique: true
    add_index :domain_blocks, :domain
  end
end
