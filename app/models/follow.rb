# frozen_string_literal: true

class Follow < ApplicationRecord
  # === バリデーション ===
  validates :actor_id, uniqueness: { scope: :target_actor_id }
  validates :ap_id, presence: true, uniqueness: true
  validates :follow_activity_ap_id, presence: true

  # 自分自身をフォローできない
  validate :cannot_follow_self

  # === アソシエーション ===
  belongs_to :actor, inverse_of: :following_relationships
  belongs_to :target_actor, class_name: 'Actor', inverse_of: :follower_relationships

  # === スコープ ===
  scope :accepted, -> { where(accepted: true) }
  scope :pending, -> { where(accepted: false) }
  scope :local, -> { joins(:actor).where(actors: { local: true }) }
  scope :remote, -> { joins(:actor).where(actors: { local: false }) }
  scope :recent, -> { order(created_at: :desc) }

  # 特定のアクターのフォロー関係
  scope :for_actor, ->(actor) { where(actor: actor) }
  scope :targeting_actor, ->(actor) { where(target_actor: actor) }

  # === コールバック ===
  before_validation :set_defaults, on: :create
  after_create :update_follower_counts, if: :accepted?
  after_update :update_follower_counts, if: :saved_change_to_accepted?
  after_destroy :update_follower_counts_on_destroy

  # === 状態管理メソッド ===

  def accepted?
    accepted
  end

  def pending?
    !accepted
  end

  def local_follow?
    actor.local?
  end

  def remote_follow?
    !actor.local?
  end

  def accept!
    return if accepted?

    update!(
      accepted: true,
      accepted_at: Time.current
    )

    # Accept アクティビティを作成（ローカルユーザーが承認する場合）
    create_accept_activity if target_actor.local?
  end

  def reject!
    return unless pending?

    # Reject アクティビティを作成（ローカルユーザーが拒否する場合）
    create_reject_activity if target_actor.local?

    destroy
  end

  def unfollow!
    # Undo アクティビティを作成（ローカルユーザーがフォロー解除する場合）
    create_undo_activity if actor.local?

    destroy
  end

  # === ActivityPub関連メソッド ===

  def activitypub_url
    ap_id
  end

  def follow_activity_url
    follow_activity_ap_id
  end

  def accept_activity_url
    accept_activity_ap_id
  end

  private

  def set_defaults
    self.accepted = false if accepted.nil?

    # ローカルアクター同士のフォローは即座に承認
    return unless actor&.local? && target_actor&.local?

    self.accepted = true
    self.accepted_at = Time.current
  end

  def cannot_follow_self
    return unless actor_id == target_actor_id

    errors.add(:target_actor, "can't follow yourself")
  end

  def update_follower_counts
    return unless accepted?

    # 非同期でカウンターを更新
    UpdateFollowerCountsJob.perform_later(actor.id, target_actor.id)
  rescue StandardError => e
    Rails.logger.error "Failed to update follower counts: #{e.message}"
    # 同期的にフォールバック
    update_follower_counts_sync
  end

  def update_follower_counts_on_destroy
    return unless accepted?

    UpdateFollowerCountsJob.perform_later(actor.id, target_actor.id)
  rescue StandardError => e
    Rails.logger.error "Failed to update follower counts: #{e.message}"
    update_follower_counts_sync
  end

  def update_follower_counts_sync
    actor.update_following_count!
    target_actor.update_followers_count!
  end

  def create_accept_activity
    Activity.create!(
      ap_id: generate_accept_activity_id,
      activity_type: 'Accept',
      actor: target_actor,
      target_ap_id: follow_activity_ap_id,
      published_at: Time.current,
      local: true,
      processed: true
    )
  end

  def create_reject_activity
    Activity.create!(
      ap_id: generate_reject_activity_id,
      activity_type: 'Reject',
      actor: target_actor,
      target_ap_id: follow_activity_ap_id,
      published_at: Time.current,
      local: true,
      processed: true
    )
  end

  def create_undo_activity
    Activity.create!(
      ap_id: generate_undo_activity_id,
      activity_type: 'Undo',
      actor: actor,
      target_ap_id: follow_activity_ap_id,
      published_at: Time.current,
      local: true,
      processed: true
    )
  end

  def generate_accept_activity_id
    "#{target_actor.ap_id}#accepts/follows/#{id}"
  end

  def generate_reject_activity_id
    "#{target_actor.ap_id}#rejects/follows/#{id}"
  end

  def generate_undo_activity_id
    "#{actor.ap_id}#undos/follows/#{id}"
  end
end
