import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const writing = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/writing' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    description: z.string(),
    tags: z.array(z.string()).default([]),
    type: z.enum(['post', 'external']).default('post'),
    externalUrl: z.string().url().optional(),
    source: z.string().optional(),
    draft: z.boolean().default(false),
  }).refine((d) => d.type !== 'external' || !!d.externalUrl, {
    message: 'external entries need externalUrl',
  }),
});

const work = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/work' }),
  schema: z.object({
    title: z.string(),
    industry: z.string(),
    workType: z.enum(['Strategy', 'Architecture', 'Engineering']),
    kpis: z.array(z.object({ label: z.string(), value: z.string() })).max(3),
    tags: z.array(z.string()).default([]),
    order: z.number(),
  }),
});

export const collections = { writing, work };
