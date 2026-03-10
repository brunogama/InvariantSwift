// Conventional Commits validation config
// https://commitlint.js.org/reference/configuration.html
// Rules: https://commitlint.js.org/reference/rules.html
'use strict';

module.exports = {
  extends: ['@commitlint/config-conventional'],

  // Built-in ignores (merge commits, revert commits, etc.) stay active.
  defaultIgnores: true,

  // Project-specific ignores.
  ignores: [
    // Coding-agent bootstrap commits produced by report_progress.
    (message) => message.trim().startsWith('Initial plan'),
    // Auto-generated changelog commits from release-on-merge.yml.
    (message) => /^docs: update changelog/.test(message.trim()),
  ],

  rules: {
    // Allow all standard types plus project-specific ones.
    'type-enum': [
      2,
      'always',
      [
        'feat',     // New feature
        'fix',      // Bug fix
        'docs',     // Documentation only
        'style',    // Formatting, no logic change
        'refactor', // Neither fix nor feature
        'perf',     // Performance improvement
        'test',     // Adding or fixing tests
        'build',    // Build system or dependency changes
        'ci',       // CI configuration
        'chore',    // Maintenance tasks
        'revert',   // Revert a previous commit
      ],
    ],

    // Subject must not end with a period.
    'subject-full-stop': [2, 'never', '.'],

    // Subject must not be empty.
    'subject-empty': [2, 'never'],

    // Type must not be empty.
    'type-empty': [2, 'never'],

    // Header line limit (type + scope + subject).
    'header-max-length': [2, 'always', 100],
  },
};
