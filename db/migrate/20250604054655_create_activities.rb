class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      # ActivityPub識別
      t.string :ap_id, null: false, index: { unique: true }
      t.string :activity_type, null: false

      # 関連情報
      t.references :actor, null: false, foreign_key: true
      t.references :object, null: true, foreign_key: true
      t.string :target_ap_id

      # ActivityPub データ
      t.json :raw_data
      t.datetime :published_at

      # 処理状態
      t.boolean :local, default: false
      t.boolean :processed, default: false
      t.datetime :processed_at

      t.timestamps
    end

    # インデックス設定
    add_index :activities, :ap_id, unique: true unless index_exists?(:activities, :ap_id)
    add_index :activities, :activity_type unless index_exists?(:activities, :activity_type)
    add_index :activities, %i[actor_id published_at] unless index_exists?(:activities, %i[actor_id published_at])
    add_index :activities, :local unless index_exists?(:activities, :local)
    add_index :activities, :processed unless index_exists?(:activities, :processed)
    add_index :activities, :target_ap_id unless index_exists?(:activities, :target_ap_id)
  end
end
