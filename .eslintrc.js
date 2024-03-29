module.exports = {
  'env': {
    'browser': true,
    'commonjs': true,
    'es2021': true
  },
  'extends': 'eslint:recommended',
  'parserOptions': {
    'ecmaVersion': 'latest'
  },
  'globals': {
    'web3': 'readonly',
    'artifacts': 'readonly',
    'contract': 'readonly',
    'before': 'readonly',
    'it': 'readonly',
    'assert': 'readonly',
    'Buffer': 'readonly',
  },
  'rules': {
    'indent': [
      'error',
      4
    ],
    'linebreak-style': [
      'error',
      'unix'
    ],
    'quotes': [
      'error',
      'single'
    ],
    'semi': [
      'error',
      'always'
    ],
    'no-shadow': [
      'error',
      {}
    ],
  }
};
