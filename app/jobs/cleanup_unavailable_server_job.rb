# frozen_string_literal: true

class CleanupUnavailableServerJob < ApplicationJob
  queue_as :default

  # 利用不可能なサーバのクリーンアップジョブ
  # @param unavailable_server_id [Integer] UnavailableServerのID
  def perform(unavailable_server_id)
    @unavailable_server = UnavailableServer.find(unavailable_server_id)

    Rails.logger.info "🧹 Starting cleanup for unavailable server: #{@unavailable_server.domain}"

    cleanup_relationships

    Rails.logger.info "✅ Cleanup completed for unavailable server: #{@unavailable_server.domain}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "❌ UnavailableServer #{unavailable_server_id} not found"
  rescue StandardError => e
    Rails.logger.error "💥 CleanupUnavailableServerJob error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  private

  def cleanup_relationships
    domain = @unavailable_server.domain

    # このドメインのユーザを取得
    domain_actors = Actor.where(domain: domain)
    actor_ids = domain_actors.pluck(:id)

    return if actor_ids.empty?

    Rails.logger.info "🔍 Found #{actor_ids.count} users from domain #{domain}"

    # フォロー関係を削除
    cleanup_follows(actor_ids, domain)

    # フォロワー数・フォロー数を更新
    update_relationship_counts(actor_ids, domain)
  end

  def cleanup_follows(actor_ids, _domain)
    # このドメインのユーザがフォローしている関係を削除
    follows_by_domain = Follow.where(actor_id: actor_ids)
    follows_by_domain_count = follows_by_domain.count
    follows_by_domain.delete_all

    # このドメインのユーザをフォローしている関係を削除
    follows_to_domain = Follow.where(target_actor_id: actor_ids)
    follows_to_domain_count = follows_to_domain.count
    follows_to_domain.delete_all

    Rails.logger.info "🗑️ Removed #{follows_by_domain_count} follows by domain users"
    Rails.logger.info "🗑️ Removed #{follows_to_domain_count} follows to domain users"
  end

  def update_relationship_counts(actor_ids, _domain)
    # 影響を受けたローカルユーザのフォロー数を更新
    affected_followers = Follow.joins(:target_actor)
                               .where(actor_id: actor_ids)
                               .where(actors: { local: true })
                               .pluck(:target_actor_id)
                               .uniq

    affected_following = Follow.joins(:actor)
                               .where(target_actor_id: actor_ids)
                               .where(actors: { local: true })
                               .pluck(:actor_id)
                               .uniq

    # フォロワー数とフォロー数を更新
    (affected_followers + affected_following).uniq.each do |actor_id|
      actor = Actor.find_by(id: actor_id, local: true)
      next unless actor

      actor.update_followers_count!
      actor.update_following_count!
    end

    Rails.logger.info "📊 Updated relationship counts for #{(affected_followers + affected_following).uniq.count} local users"
  end
end
