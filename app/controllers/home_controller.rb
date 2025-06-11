# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @posts = load_public_timeline
    @page_title = I18n.t('pages.home.title')
  end

  private

  def load_public_timeline
    ActivityPubObject.joins(:actor)
                     .where(actors: { local: true })
                     .where(visibility: %w[public unlisted])
                     .includes(:actor, :media_attachments)
                     .order(published_at: :desc)
                     .limit(30)
  end
end
