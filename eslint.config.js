module.exports = [
  {
  files: ['**/*.js'],
  ignores: ['dependencies/**'],
  languageOptions: {
        ecmaVersion: 'latest',
    globals: {
        web3: 'readonly',
        artifacts: 'readonly',
        contract: 'readonly',
        before: 'readonly',
        it: 'readonly',
        assert: 'readonly',
        Buffer: 'readonly',
    }
  },
    rules: {
        'linebreak-style': ['error', 'unix'],
        quotes: ['error', 'single'],
        semi: ['error', 'always'],
        'no-shadow': ['error', {}],
        'no-unused-vars': [
            'warn',
            { 'vars': 'all', 'varsIgnorePattern': '^_', 'args': 'after-used', 'argsIgnorePattern': '^_' }
        ],
    },
  },
  {
    ignores: ['dependencies/**'],
  }
  ];
