class CreateUserLimits < ActiveRecord::Migration[8.0]
  def change
    create_table :user_limits, id: :string do |t|
      # 関連付け
      t.references :actor, type: :string, null: true, foreign_key: true
      # actor_id = nil はシステム制限（max_accounts）

      # 制限設定
      t.string :limit_type, null: false, limit: 50
      t.integer :limit_value, null: false
      t.integer :current_usage, null: false, default: 0
      t.boolean :enabled, null: false, default: true

      # タイムスタンプ
      t.timestamps
    end

    # インデックス
    add_index :user_limits, %i[actor_id limit_type], unique: true
    add_index :user_limits, :limit_type
    add_index :user_limits, :enabled

    # システム制限用の特別インデックス
    add_index :user_limits, :limit_type,
              where: 'actor_id IS NULL',
              name: 'index_user_limits_on_system_limits'
  end
end
