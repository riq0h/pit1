class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      # 基本関係
      t.references :actor, null: false, foreign_key: true
      t.references :target_actor, null: false, foreign_key: { to_table: :actors }

      # ActivityPub情報
      t.string :ap_id, null: false, index: { unique: true }
      t.string :follow_activity_ap_id
      t.string :accept_activity_ap_id

      # 状態管理
      t.boolean :accepted, default: false
      t.datetime :accepted_at
      t.boolean :blocked, default: false

      t.timestamps
    end

    # インデックス設定
    add_index :follows, %i[actor_id target_actor_id], unique: true unless index_exists?(:follows,
                                                                                        %i[actor_id target_actor_id])
    add_index :follows, :ap_id, unique: true unless index_exists?(:follows, :ap_id)
    add_index :follows, :accepted unless index_exists?(:follows, :accepted)
    add_index :follows, :follow_activity_ap_id unless index_exists?(:follows, :follow_activity_ap_id)

    # フォローカウント更新トリガー
    execute <<-SQL
      CREATE TRIGGER follow_insert_update_counts
      AFTER INSERT ON follows
      WHEN NEW.accepted = 1
      BEGIN
        UPDATE actors SET following_count = following_count + 1 WHERE id = NEW.actor_id;
        UPDATE actors SET followers_count = followers_count + 1 WHERE id = NEW.target_actor_id;
      END;

      CREATE TRIGGER follow_delete_update_counts
      AFTER DELETE ON follows
      WHEN OLD.accepted = 1
      BEGIN
        UPDATE actors SET following_count = following_count - 1 WHERE id = OLD.actor_id;
        UPDATE actors SET followers_count = followers_count - 1 WHERE id = OLD.target_actor_id;
      END;

      CREATE TRIGGER follow_accept_update_counts
      AFTER UPDATE ON follows
      WHEN OLD.accepted = 0 AND NEW.accepted = 1
      BEGIN
        UPDATE actors SET following_count = following_count + 1 WHERE id = NEW.actor_id;
        UPDATE actors SET followers_count = followers_count + 1 WHERE id = NEW.target_actor_id;
      END;
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS follow_accept_update_counts'
    execute 'DROP TRIGGER IF EXISTS follow_delete_update_counts'
    execute 'DROP TRIGGER IF EXISTS follow_insert_update_counts'
    drop_table :follows
  end
end
