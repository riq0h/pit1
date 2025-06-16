class RemoveLegacyImageFieldsFromActors < ActiveRecord::Migration[8.0]
  def change
    # レガシー画像フィールドを削除（Active Storageに移行済み）
    remove_column :actors, :avatar_url, :string
    remove_column :actors, :header_url, :string
    remove_column :actors, :icon_url, :string
  end
end
