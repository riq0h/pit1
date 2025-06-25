// config/importmap.rbでインポートマップを設定してください。詳細: https://github.com/rails/importmap-rails
import '@hotwired/turbo-rails';
import 'controllers';

// ActivityPubクライアント初期化
document.addEventListener('DOMContentLoaded', () => {
  if (typeof ActivityPubClient !== 'undefined') {
    window.apClient = new ActivityPubClient(window.location.origin);
  }
});

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/service-worker.js');
}
