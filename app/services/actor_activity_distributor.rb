# frozen_string_literal: true

class ActorActivityDistributor
  def initialize(actor)
    @actor = actor
  end

  def follow!(target_actor_or_uri)
    target_actor = resolve_target_actor(target_actor_or_uri)
    return nil unless target_actor

    Follow.create!(actor: actor, target_actor: target_actor)
  end

  def unfollow!(target_actor_or_uri)
    target_actor = resolve_target_actor(target_actor_or_uri)
    return unless target_actor

    follow = actor.follows.find_by(target_actor: target_actor)
    follow&.unfollow!
  end

  def should_distribute_profile_update?
    return false unless actor.local?
    return false unless actor.saved_changes.keys.intersect?(%w[display_name note avatar header discoverable manually_approves_followers])

    true
  end

  def distribute_profile_update
    return unless should_distribute_profile_update?

    Rails.logger.info "👤 Distributing profile update for #{actor.username}"
    SendProfileUpdateJob.perform_later(actor.id)
  end

  private

  attr_reader :actor

  def resolve_target_actor(target_actor_or_uri)
    case target_actor_or_uri
    when Actor
      target_actor_or_uri
    when String
      Actor.find_by(ap_id: target_actor_or_uri) || resolve_remote_actor(target_actor_or_uri)
    end
  end

  def resolve_remote_actor(uri)
    resolver = Search::RemoteResolverService.new
    resolver.resolve_remote_account(uri)
  rescue StandardError => e
    Rails.logger.error "Failed to resolve remote actor #{uri}: #{e.message}"
    nil
  end
end
