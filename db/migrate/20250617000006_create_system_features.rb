# frozen_string_literal: true

class CreateSystemFeatures < ActiveRecord::Migration[8.0]
  def change
    # User limits and quotas
    create_table :user_limits, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: { unique: true }
      
      # Limit types and values
      t.string :limit_type, null: false
      t.integer :limit_value, null: false
      t.integer :current_usage, default: 0
      t.datetime :reset_at
      
      t.timestamps
    end

    add_index :user_limits, [:actor_id, :limit_type], unique: true
  end
end