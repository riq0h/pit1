# frozen_string_literal: true

class AddActivityPubFieldsToActors < ActiveRecord::Migration[8.0]
  def change
    # ActivityPub標準フィールド追加（重複カラムを除外）
    add_column :actors, :actor_type, :string, default: 'Person' unless column_exists?(:actors, :actor_type)
    add_column :actors, :discoverable, :boolean, default: true unless column_exists?(:actors, :discoverable)
    add_column :actors, :manually_approves_followers, :boolean, default: false unless column_exists?(:actors, :manually_approves_followers)
    add_column :actors, :featured_url, :string unless column_exists?(:actors, :featured_url)
    add_column :actors, :icon_url, :string unless column_exists?(:actors, :icon_url)
    
    # パフォーマンス向上用インデックス（重複チェック）
    add_index :actors, :actor_type unless index_exists?(:actors, :actor_type)
    add_index :actors, :discoverable unless index_exists?(:actors, :discoverable)
    add_index :actors, :manually_approves_followers unless index_exists?(:actors, :manually_approves_followers)
  end
end