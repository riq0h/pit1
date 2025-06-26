# frozen_string_literal: true

module SearchSerializationHelper
  include AccountSerializer
  include SearchStatusSerializer
  include SearchHashtagSerializer

  private

  # 検索用の軽量版アカウントシリアライゼーション
  def serialized_account(actor)
    super(actor, lightweight: true)
  end
end
