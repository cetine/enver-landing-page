// Type stub for Pagefind's runtime bundle. The real module is generated at
// build time (`pagefind --site dist`) and served from /pagefind/pagefind.js,
// which does not exist during type-checking and ships no types. The tsconfig
// `paths` mapping points the "/pagefind/pagefind.js" import here so `astro
// check` can resolve it; at runtime the actual bundle is loaded instead.
export declare function search(
  term: string,
): Promise<{ results: Array<{ data: () => Promise<PagefindDocument> }> }>;
export declare function options(opts: Record<string, unknown>): Promise<void>;

export interface PagefindDocument {
  url: string;
  excerpt: string;
  meta?: { title?: string };
}

declare const pagefind: { search: typeof search; options: typeof options };
export default pagefind;
