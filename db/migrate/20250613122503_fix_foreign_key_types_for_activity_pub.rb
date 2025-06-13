class FixForeignKeyTypesForActivityPub < ActiveRecord::Migration[8.0]
  def up
    # favourites table
    change_column :favourites, :actor_id, :string
    change_column :favourites, :object_id, :string

    # reblogs table  
    change_column :reblogs, :actor_id, :string
    change_column :reblogs, :object_id, :string

    # mentions table
    change_column :mentions, :actor_id, :string
    change_column :mentions, :object_id, :string

    # blocks table
    change_column :blocks, :actor_id, :string
    change_column :blocks, :target_actor_id, :string

    # mutes table
    change_column :mutes, :actor_id, :string
    change_column :mutes, :target_actor_id, :string

    # domain_blocks table
    change_column :domain_blocks, :actor_id, :string

    # object_tags table
    change_column :object_tags, :object_id, :string
  end

  def down
    # Note: This rollback could cause data loss if IDs exceed integer range
    change_column :favourites, :actor_id, :integer
    change_column :favourites, :object_id, :integer

    change_column :reblogs, :actor_id, :integer
    change_column :reblogs, :object_id, :integer

    change_column :mentions, :actor_id, :integer
    change_column :mentions, :object_id, :integer

    change_column :blocks, :actor_id, :integer
    change_column :blocks, :target_actor_id, :integer

    change_column :mutes, :actor_id, :integer
    change_column :mutes, :target_actor_id, :integer

    change_column :domain_blocks, :actor_id, :integer

    change_column :object_tags, :object_id, :integer
  end
end