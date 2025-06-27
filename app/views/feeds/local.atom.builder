# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.feed 'xmlns' => 'http://www.w3.org/2005/Atom' do
  xml.title blog_title.to_s
  xml.subtitle 'ローカルインスタンスの投稿フィード'
  xml.id request.original_url
  xml.link 'rel' => 'alternate', 'type' => 'text/html', 'href' => root_url
  xml.link 'rel' => 'self', 'type' => 'application/atom+xml', 'href' => request.original_url
  xml.updated @posts.first&.published_at&.iso8601
  xml.generator 'letter'

  @posts.each do |post|
    xml.entry do
      xml.title truncate(strip_tags(post.content), length: 100)
      xml.content auto_link_urls(post.content), type: 'html'
      xml.id post_html_url(post.actor.username, post.id)
      xml.link 'rel' => 'alternate', 'type' => 'text/html', 'href' => post_html_url(post.actor.username, post.id)
      xml.published post.published_at.iso8601
      xml.updated post.published_at.iso8601

      xml.author do
        xml.name post.actor.display_name.presence || post.actor.username
        xml.uri profile_url(post.actor.username)
      end

      # メディア添付があれば追加
      if post.media_attachments.any?
        post.media_attachments.each do |media|
          xml.link 'rel' => 'enclosure', 'type' => media.content_type, 'href' => media.url
        end
      end
    end
  end
end
