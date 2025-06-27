# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss :version => '2.0', 'xmlns:content' => 'http://purl.org/rss/1.0/modules/content/' do
  xml.channel do
    xml.title "#{@actor.username} | #{blog_title}"
    xml.description @actor.note.present? ? strip_tags(@actor.note) : "#{@actor.display_name.presence || @actor.username}の投稿フィード"
    xml.link profile_url(@actor.username)
    xml.language 'ja'
    xml.lastBuildDate @posts.first&.published_at&.rfc822
    xml.generator 'letter'

    @posts.each do |post|
      xml.item do
        xml.title truncate(strip_tags(post.content), length: 100)
        xml.description do
          xml.cdata! auto_link_urls(post.content)
        end
        xml.pubDate post.published_at.rfc822
        xml.link post_html_url(@actor.username, post.id)
        xml.guid post_html_url(@actor.username, post.id), isPermaLink: 'true'
        xml.author "#{@actor.display_name.presence || @actor.username} <noreply@#{request.host}>"

        # メディア添付があれば追加
        if post.media_attachments.any?
          post.media_attachments.each do |media|
            xml.enclosure url: media.url, type: media.content_type, length: 0
          end
        end
      end
    end
  end
end
