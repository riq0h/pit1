class AddPasswordDigestToActors < ActiveRecord::Migration[8.0]
  def change
    add_column :actors, :password_digest, :string
  end
end
