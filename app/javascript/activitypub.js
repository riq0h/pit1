// ActivityPub Client-side utilities

class ActivityPubClient {
  constructor(baseUrl) {
    this.baseUrl = baseUrl;
    this.headers = {
      Accept: 'application/activity+json',
      'Content-Type': 'application/activity+json'
    };
  }

  async fetchActor(username) {
    try {
      const response = await fetch(`${this.baseUrl}/users/${username}`, {
        headers: this.headers
      });
      return await response.json();
    } catch (error) {
      console.error('Failed to fetch actor:', error);
      return null;
    }
  }

  validateActorUrl(url) {
    try {
      const parsedUrl = new globalThis.URL(url);
      return parsedUrl.protocol === 'https:' || parsedUrl.protocol === 'http:';
    } catch {
      return false;
    }
  }
}

const WebfingerUtil = {
  parseHandle(handle) {
    const match = handle.match(/^@?([^@]+)@(.+)$/);
    return match ? { username: match[1], domain: match[2] } : null;
  }
};

globalThis.ActivityPubClient = ActivityPubClient;
globalThis.WebfingerUtil = WebfingerUtil;
