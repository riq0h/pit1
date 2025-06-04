# db/migrate/006_create_user_limits.rb
class CreateUserLimits < ActiveRecord::Migration[8.0]
  def change
    create_table :user_limits do |t|
      t.integer :current_users, default: 0
      t.integer :max_users, default: 2
      t.integer :max_post_length, default: 9999
      t.boolean :registration_open, default: false
      t.timestamps
    end
  end
end
