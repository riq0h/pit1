class FixActorTrigger < ActiveRecord::Migration[8.0]
  def up
    # 既存のトリガーを削除
    execute 'DROP TRIGGER IF EXISTS limit_local_actors;'
    
    # シンプルなアプローチ: Railsレベルでバリデーション、トリガーは削除
    # local_account_slotは手動で設定
  end
  
  def down
    # 何もしない（元のトリガーは問題があったため復元しない）
  end
end
