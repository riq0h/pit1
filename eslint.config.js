import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    files: ['app/javascript/**/*.js'],
    languageOptions: {
      ecmaVersion: 2021,
      sourceType: 'module',
      globals: {
        window: 'readonly',
        document: 'readonly',
        console: 'readonly',
        navigator: 'readonly',
        fetch: 'readonly',
        URL: 'readonly',
        globalThis: 'readonly',
        ActivityPubClient: 'writable',
        WebfingerUtil: 'writable'
      }
    },
    rules: {
      'no-console': ['warn', { allow: ['error', 'warn'] }],
      'object-shorthand': 'error'
    }
  }
];
