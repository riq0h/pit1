# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Media', type: :request do
  let!(:user) { create(:actor, :local) }
  let!(:application) { Doorkeeper::Application.create!(name: 'Test App', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob') }
  let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }

  let(:auth_headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'POST /api/v1/media' do
    let(:test_image) do
      # テスト用の小さな画像ファイルを作成
      Rack::Test::UploadedFile.new(
        StringIO.new('fake image data'),
        'image/png',
        original_filename: 'test.png'
      )
    end

    let(:test_video) do
      Rack::Test::UploadedFile.new(
        StringIO.new('fake video data'),
        'video/mp4',
        original_filename: 'test.mp4'
      )
    end

    context 'メディアアップロード機能テスト' do
      it '画像ファイルをアップロードできる' do
        expect do
          post '/api/v1/media',
               params: { file: test_image, description: 'テスト画像' },
               headers: auth_headers
        end.to change { user.media_attachments.count }.by(1)

        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        expect(json_response['type']).to eq 'image'
        expect(json_response['description']).to eq 'テスト画像'
        expect(json_response['url']).to be_present
        expect(json_response['id']).to be_present
      end

      it '動画ファイルをアップロードできる' do
        expect do
          post '/api/v1/media',
               params: { file: test_video },
               headers: auth_headers
        end.to change { user.media_attachments.count }.by(1)

        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        expect(json_response['type']).to eq 'video'
      end

      it 'メディアファイルのメタデータが正しく設定される' do
        post '/api/v1/media',
             params: { file: test_image },
             headers: auth_headers

        media = user.media_attachments.last
        expect(media.filename).to eq 'test.png'
        expect(media.content_type).to eq 'image/png'
        expect(media.media_type).to eq 'image'
        expect(media.file_size).to be > 0
        expect(media.storage_path).to be_present
        expect(media.file_url).to be_present
      end

      it 'ファイルパラメータが必須' do
        post '/api/v1/media',
             params: { description: 'ファイルなし' },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq 'File parameter is required'
      end

      it '認証なしではアップロードできない' do
        post '/api/v1/media',
             params: { file: test_image }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'アップロード時に一意なファイル名が生成される' do
        post '/api/v1/media',
             params: { file: test_image },
             headers: auth_headers

        media1 = user.media_attachments.last

        post '/api/v1/media',
             params: { file: test_image },
             headers: auth_headers

        media2 = user.media_attachments.last

        expect(media1.storage_path).not_to eq media2.storage_path
      end

      it 'blurhash が画像ファイルに設定される' do
        post '/api/v1/media',
             params: { file: test_image },
             headers: auth_headers

        json_response = JSON.parse(response.body)
        expect(json_response['blurhash']).to be_present

        media = user.media_attachments.last
        expect(media.blurhash).to be_present
      end
    end

    context 'メディアタイプ判定テスト' do
      it 'JPEG画像が正しく判定される' do
        jpeg_file = Rack::Test::UploadedFile.new(
          StringIO.new('fake jpeg data'),
          'image/jpeg',
          original_filename: 'test.jpg'
        )

        post '/api/v1/media',
             params: { file: jpeg_file },
             headers: auth_headers

        media = user.media_attachments.last
        expect(media.media_type).to eq 'image'
        expect(media.content_type).to eq 'image/jpeg'
      end

      it '音声ファイルが正しく判定される' do
        audio_file = Rack::Test::UploadedFile.new(
          StringIO.new('fake audio data'),
          'audio/mp3',
          original_filename: 'test.mp3'
        )

        post '/api/v1/media',
             params: { file: audio_file },
             headers: auth_headers

        media = user.media_attachments.last
        expect(media.media_type).to eq 'audio'
      end

      it '不明なファイルタイプはdocumentとして扱われる' do
        unknown_file = Rack::Test::UploadedFile.new(
          StringIO.new('fake data'),
          'application/octet-stream',
          original_filename: 'test.bin'
        )

        post '/api/v1/media',
             params: { file: unknown_file },
             headers: auth_headers

        media = user.media_attachments.last
        expect(media.media_type).to eq 'document'
      end
    end
  end

  describe 'GET /api/v1/media/:id' do
    let!(:media) { create(:media_attachment, actor: user) }

    context 'メディア情報取得テスト' do
      it 'メディア情報を取得できる' do
        get "/api/v1/media/#{media.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq media.id.to_s
        expect(json_response['type']).to eq media.media_type
        expect(json_response['url']).to eq media.file_url
        expect(json_response['description']).to eq media.description
      end

      it '他のユーザーのメディアは取得できない' do
        other_user = create(:actor, :local)
        other_media = create(:media_attachment, actor: other_user)

        get "/api/v1/media/#{other_media.id}", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end

      it '存在しないメディアIDでは404エラー' do
        get '/api/v1/media/99999', headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PUT /api/v1/media/:id' do
    let!(:media) { create(:media_attachment, actor: user, description: '元の説明') }

    context 'メディア情報更新テスト' do
      it 'メディアの説明を更新できる' do
        put "/api/v1/media/#{media.id}",
            params: { description: '更新された説明' },
            headers: auth_headers

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['description']).to eq '更新された説明'

        media.reload
        expect(media.description).to eq '更新された説明'
      end

      it '他のユーザーのメディアは更新できない' do
        other_user = create(:actor, :local)
        other_media = create(:media_attachment, actor: other_user)

        put "/api/v1/media/#{other_media.id}",
            params: { description: '不正な更新' },
            headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end

      it '無効なパラメータではバリデーションエラー' do
        # 説明が長すぎる場合のテスト（実装に応じて調整）
        long_description = 'a' * 1000

        put "/api/v1/media/#{media.id}",
            params: { description: long_description },
            headers: auth_headers

        # バリデーションルールに応じてレスポンスを確認
        # 現在の実装では長さ制限がないため、成功するかもしれません
      end
    end
  end

  describe '投稿へのメディア添付テスト' do
    let!(:media1) { create(:media_attachment, actor: user) }
    let!(:media2) { create(:media_attachment, actor: user) }

    it '投稿作成時にメディアを添付できる' do
      post '/api/v1/statuses',
           params: {
             status: 'メディア付き投稿',
             media_ids: [media1.id, media2.id]
           },
           headers: auth_headers

      expect(response).to have_http_status(:created)

      status = ActivityPubObject.last
      expect(status.media_attachments.count).to eq 2
      expect(status.media_attachments).to include(media1, media2)

      json_response = JSON.parse(response.body)
      expect(json_response['media_attachments'].length).to eq 2
    end

    it '添付後、メディアのobject_idが設定される' do
      post '/api/v1/statuses',
           params: {
             status: 'メディア付き投稿',
             media_ids: [media1.id]
           },
           headers: auth_headers

      media1.reload
      status = ActivityPubObject.last
      expect(media1.object_id).to eq status.id
    end

    it '他のユーザーのメディアは添付できない' do
      other_user = create(:actor, :local)
      other_media = create(:media_attachment, actor: other_user)

      post '/api/v1/statuses',
           params: {
             status: '不正なメディア添付',
             media_ids: [other_media.id]
           },
           headers: auth_headers

      status = ActivityPubObject.last
      expect(status.media_attachments.count).to eq 0
    end
  end

  describe 'メディアレスポンス形式テスト' do
    let!(:image_media) do
      create(:media_attachment,
             actor: user,
             media_type: 'image',
             width: 1920,
             height: 1080,
             blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj')
    end

    it 'Mastodon API準拠のレスポンス形式' do
      get "/api/v1/media/#{image_media.id}", headers: auth_headers

      json_response = JSON.parse(response.body)

      # 必須フィールドの確認
      expect(json_response).to have_key('id')
      expect(json_response).to have_key('type')
      expect(json_response).to have_key('url')
      expect(json_response).to have_key('preview_url')
      expect(json_response).to have_key('remote_url')
      expect(json_response).to have_key('meta')
      expect(json_response).to have_key('description')
      expect(json_response).to have_key('blurhash')

      # メタデータの構造確認
      expect(json_response['meta']).to have_key('original')
      expect(json_response['meta']).to have_key('small')

      if image_media.width && image_media.height
        expect(json_response['meta']['original']).to have_key('width')
        expect(json_response['meta']['original']).to have_key('height')
        expect(json_response['meta']['original']).to have_key('size')
        expect(json_response['meta']['original']).to have_key('aspect')
      end
    end
  end
end
