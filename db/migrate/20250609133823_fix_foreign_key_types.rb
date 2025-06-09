class FixForeignKeyTypes < ActiveRecord::Migration[8.0]
  def up
    # 外部キー制約を削除
    remove_foreign_key :activities, :actors if foreign_key_exists?(:activities, :actors)
    remove_foreign_key :activities, :objects if foreign_key_exists?(:activities, :objects)
    
    # actor_idカラムの型を文字列に変更
    change_column :activities, :actor_id, :string
    
    # object_idカラムの型を文字列に変更
    change_column :activities, :object_id, :string
    
    # 外部キー制約を再追加
    add_foreign_key :activities, :actors, column: :actor_id
    add_foreign_key :activities, :objects, column: :object_id
  end
  
  def down
    # 元に戻す場合は整数型に変更（データ移行が必要）
    remove_foreign_key :activities, :actors if foreign_key_exists?(:activities, :actors)
    remove_foreign_key :activities, :objects if foreign_key_exists?(:activities, :objects)
    
    change_column :activities, :actor_id, :integer
    change_column :activities, :object_id, :integer
    
    add_foreign_key :activities, :actors, column: :actor_id
    add_foreign_key :activities, :objects, column: :object_id
  end
end
