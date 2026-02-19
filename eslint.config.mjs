
// ESLint: Checks your code style and finds bugs before you run it 
// (e.g., "you forgot a semicolon" or "this variable is never used").

import js from "@eslint/js";
import globals from "globals";

export default [
  // 1. Apply recommended JavaScript rules
  js.configs.recommended,

  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.node,  // Recognizes 'process', 'require', etc.
        ...globals.jest,  // Recognizes 'test', 'expect', 'describe' for taskController.test.js
      },
    },
    rules: {
      "no-unused-vars": "warn",
      "no-console": "off", // Keep off for DevOps projects to see logs
    },
  },

  // 2. Ignore these folders (replacing the old .eslintignore)
  {
    ignores: ["node_modules/", "coverage/", "webpack.config.js"],
  },
];

