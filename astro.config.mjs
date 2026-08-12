import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import preact from '@astrojs/preact';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';
import yaml from '@rollup/plugin-yaml';
import rehypeWorkHeadingIds from './src/lib/rehype-work-heading-ids.mjs';

export default defineConfig({
  site: 'https://envercetin.de',
  trailingSlash: 'never',
  markdown: {
    rehypePlugins: [rehypeWorkHeadingIds],
  },
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'de'],
    routing: { prefixDefaultLocale: false },
  },
  integrations: [
    // Writing posts stay plain markdown unless they need a figure; `.mdx` lets
    // such a post import one shared, localized diagram component instead of
    // pasting the same inline SVG into both the EN and DE file. MDX inherits
    // the `markdown` config above, so heading ids behave identically.
    mdx(),
    preact({ compat: true }),
    sitemap({
      i18n: { defaultLocale: 'en', locales: { en: 'en', de: 'de' } },
      // Legal pages + the internal plate-motion preview are noindex — keep them
      // out of the sitemap too.
      filter: (page) => {
        const path = page.replace('https://envercetin.de', '').replace(/\/$/, '');
        return !['/impressum', '/datenschutz', '/de/impressum', '/de/datenschutz', '/design/plate-motion'].includes(path);
      },
    }),
  ],
  vite: {
    plugins: [tailwindcss(), yaml()],
    build: {
      rollupOptions: {
        // Pagefind's bundle only exists after `pagefind --site dist` runs in
        // postbuild; it is loaded at runtime, so keep Rollup from resolving it.
        external: ['/pagefind/pagefind.js'],
      },
    },
  },
});
