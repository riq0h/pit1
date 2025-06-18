class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :account, null: false, foreign_key: { to_table: :actors }
      t.references :from_account, null: false, foreign_key: { to_table: :actors }
      t.string :activity_type, null: false
      t.string :activity_id, null: false
      t.string :notification_type, null: false
      t.boolean :read, default: false, null: false

      t.timestamps
    end

    add_index :notifications, [:account_id, :created_at]
    add_index :notifications, [:account_id, :notification_type]
    add_index :notifications, [:account_id, :read]
  end
end