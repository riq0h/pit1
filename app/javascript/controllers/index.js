// importmapからcontrollers/**/*_controller経由でコントローラーをインポートし登録
import { application } from 'controllers/application';
import { eagerLoadControllersFrom } from '@hotwired/stimulus-loading';
eagerLoadControllersFrom('controllers', application);
