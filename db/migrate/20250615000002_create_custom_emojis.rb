# frozen_string_literal: true

class CreateCustomEmojis < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_emojis, id: :string do |t|
      t.string :shortcode, null: false
      t.string :domain, null: true  # null for local emojis
      t.string :uri, null: true     # ActivityPub URI for remote emojis
      t.string :image_url, null: true # URL for remote emoji images
      t.boolean :visible_in_picker, default: true
      t.boolean :disabled, default: false
      t.string :category_id, null: true  # for future categorization
      
      t.timestamps null: false

      # インデックス
      t.index [:shortcode, :domain], unique: true
      t.index :domain
      t.index :disabled
      t.index :visible_in_picker
      t.index :shortcode
    end
  end
end