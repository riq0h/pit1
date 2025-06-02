import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    files: ['app/javascript/**/*.js'],
    ignores: [
      'node_modules/**',
      'app/assets/builds/**',
      'public/assets/**',
      'vendor/**',
      'tmp/**',
      'storage/**'
    ],

    languageOptions: {
      ecmaVersion: 2021,
      sourceType: 'module',
      globals: {
        window: 'readonly',
        document: 'readonly',
        console: 'readonly',
        Turbo: 'readonly',
        Stimulus: 'readonly',
        application: 'readonly',
        ActivityPub: 'readonly'
      }
    },

    rules: {
      'no-console': 'warn',
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-undef': 'error',
      'prefer-const': 'error',
      'no-var': 'error',
      'no-eval': 'error',
      'no-implied-eval': 'error',
      eqeqeq: 'error',
      curly: 'error',
      'brace-style': ['error', '1tbs'],
      'object-shorthand': 'error',
      'quote-props': ['error', 'as-needed']
    }
  }
];
