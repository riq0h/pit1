// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import '@hotwired/turbo-rails';
import 'controllers';

// ActivityPub client initialization
document.addEventListener('DOMContentLoaded', () => {
  if (typeof ActivityPubClient !== 'undefined') {
    window.apClient = new ActivityPubClient(window.location.origin);
  }
});

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/service-worker.js');
}
