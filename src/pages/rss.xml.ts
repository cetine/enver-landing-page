import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import type { APIContext } from 'astro';

export async function GET(context: APIContext) {
  const entries = await getCollection('writing', ({ id, data }) => id.startsWith('en/') && !data.draft);
  return rss({
    title: 'Enver Cetin · Writing',
    description: 'Enterprise AI, agentic systems, applied automation.',
    site: context.site!,
    items: entries.map((e) => ({
      title: e.data.title,
      description: e.data.description,
      pubDate: e.data.date,
      link: e.data.type === 'external' ? e.data.externalUrl! : `/writing/${e.id.split('/')[1]}`,
    })),
  });
}
