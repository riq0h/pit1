# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Debug Favourite API', type: :request do
  let!(:user) { create(:actor, :local) }
  let!(:application) { Doorkeeper::Application.create!(name: 'Test App', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob') }
  let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }
  let!(:other_user) { create(:actor, :local) }
  let!(:other_status) { create(:activity_pub_object, actor: other_user, object_type: 'Note', content: '他のユーザーの投稿') }

  let(:auth_headers) { { 'Authorization' => "Bearer #{token.token}" } }

  it 'デバッグ用テスト' do
    puts "User ID: #{user.id}"
    puts "Other Status ID: #{other_status.id}"
    puts "Auth headers: #{auth_headers}"

    post "/api/v1/statuses/#{other_status.id}/favourite", headers: auth_headers

    puts "Response status: #{response.status}"
    puts "Response body: #{begin
      response.parsed_body
    rescue StandardError
      response.body
    end}"
    puts "User favourites count: #{user.favourites.count}"
    puts "Favourites in DB: #{Favourite.count}"

    expect(true).to be true # 常に成功するテスト
  end
end
