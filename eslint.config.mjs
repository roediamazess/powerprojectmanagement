import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    rules: {
      "@next/next/no-sync-scripts": "off",
      "@next/next/no-img-element": "off",
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    "public/**",
    "frontend/**",
    "backend/**",
    "infra/**",
    "envato-template/**",
    "laravel-app/**",
    "laravel-app-prebuilt-*/**",
    "laravel-backend/**",
    "**/vendor/**",
    "**/storage/**",
    "**/bootstrap/cache/**",
  ]),
]);

export default eslintConfig;
