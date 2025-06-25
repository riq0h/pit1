import { Application } from '@hotwired/stimulus';

const application = Application.start();

// デバッグ用の設定
application.debug = false;
window.Stimulus = application;

export { application };
