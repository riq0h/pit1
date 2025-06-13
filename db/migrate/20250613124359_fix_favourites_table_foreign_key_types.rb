class FixFavouritesTableForeignKeyTypes < ActiveRecord::Migration[8.0]
  def up
    # Fix favourites table foreign key types to match referenced tables
    # actors.id is integer, so actor_id should be integer
    # objects.id is string, so object_id should remain string
    
    change_column :favourites, :actor_id, :integer
    # object_id stays as string (varchar)
    
    # Also fix other ActivityPub tables
    change_column :reblogs, :actor_id, :integer if table_exists?(:reblogs)
    # reblogs.object_id stays as string
    
    change_column :mentions, :actor_id, :integer if table_exists?(:mentions)
    # mentions.object_id stays as string
    
    change_column :blocks, :actor_id, :integer if table_exists?(:blocks)
    change_column :blocks, :target_actor_id, :integer if table_exists?(:blocks)
    
    change_column :mutes, :actor_id, :integer if table_exists?(:mutes)
    change_column :mutes, :target_actor_id, :integer if table_exists?(:mutes)
    
    change_column :domain_blocks, :actor_id, :integer if table_exists?(:domain_blocks)
  end

  def down
    change_column :favourites, :actor_id, :string
    
    change_column :reblogs, :actor_id, :string if table_exists?(:reblogs)
    change_column :mentions, :actor_id, :string if table_exists?(:mentions)
    change_column :blocks, :actor_id, :string if table_exists?(:blocks)
    change_column :blocks, :target_actor_id, :string if table_exists?(:blocks)
    change_column :mutes, :actor_id, :string if table_exists?(:mutes)
    change_column :mutes, :target_actor_id, :string if table_exists?(:mutes)
    change_column :domain_blocks, :actor_id, :string if table_exists?(:domain_blocks)
  end
end