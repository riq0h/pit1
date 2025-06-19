# frozen_string_literal: true

class CreateMediaAndFiles < ActiveRecord::Migration[8.0]
  def change
    # Media attachments
    create_table :media_attachments, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.references :object, foreign_key: { to_table: :objects }, type: :string, null: true, index: true
      t.string :media_type, null: false
      t.string :url
      t.string :remote_url
      t.string :thumbnail_url
      t.string :file_name
      t.integer :file_size
      t.string :content_type
      
      # Image/video metadata
      t.integer :width
      t.integer :height
      t.string :blurhash
      t.text :description
      t.text :metadata
      
      # Processing status
      t.string :processing_status, default: 'pending'
      t.boolean :processed, default: false
      
      t.timestamps
    end

    # Custom emojis (using integer IDs for compatibility)
    create_table :custom_emojis, id: :integer do |t|
      t.string :shortcode, null: false
      t.string :domain
      t.string :uri
      t.string :image_url
      t.boolean :visible_in_picker, default: true
      t.boolean :disabled, default: false
      t.string :category_id
      
      t.timestamps
    end

    add_index :custom_emojis, [:shortcode, :domain], unique: true
    add_index :custom_emojis, :shortcode
  end
end