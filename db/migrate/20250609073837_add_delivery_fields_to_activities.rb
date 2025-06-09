# frozen_string_literal: true

class AddDeliveryFieldsToActivities < ActiveRecord::Migration[8.0]
  def change
    # 配信状態追跡用フィールド
    add_column :activities, :delivered, :boolean, default: false, null: false
    add_column :activities, :delivered_at, :datetime
    add_column :activities, :delivery_attempts, :integer, default: 0, null: false
    add_column :activities, :last_delivery_error, :text
    
    # パフォーマンス向上用インデックス
    add_index :activities, :delivered
    add_index :activities, :delivered_at
    add_index :activities, [:local, :delivered]
  end
end