import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';
import yaml from '@rollup/plugin-yaml';

export default defineConfig({
  site: 'https://envercetin.de',
  trailingSlash: 'never',
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'de'],
    routing: { prefixDefaultLocale: false },
  },
  integrations: [
    react(),
    sitemap({
      i18n: { defaultLocale: 'en', locales: { en: 'en', de: 'de' } },
    }),
  ],
  vite: { plugins: [tailwindcss(), yaml()] },
});
