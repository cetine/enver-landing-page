// Prefixes heading ids with the source file's basename for markdown under
// content/work/, so rendering multiple case bodies on the single /work page
// cannot emit duplicate ids (six `id="challenge"`, etc.) — invalid HTML.
//
// Runs BEFORE Astro's built-in rehypeHeadingIds, which only slugs a heading
// when `node.properties.id` is not already a string and then records the final
// id in `headings[].slug`. Because we set the id first, Astro reuses it verbatim
// AND keeps `headings` metadata consistent with the rendered id — for every
// collection. The path guard leaves the `writing` collection untouched, so its
// default slugs stay intact for the Task 11 post TOC.
//
// Dependency-free (own tree walker) to avoid coupling to transitive packages.

const HEADING = /^h[1-6]$/;

function walk(node, visit) {
  visit(node);
  const kids = node.children;
  if (kids) for (const child of kids) walk(child, visit);
}

function textOf(node) {
  let out = '';
  walk(node, (n) => {
    if (n.type === 'text' || n.type === 'raw') out += n.value ?? '';
  });
  return out;
}

function slugify(text) {
  return text
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-+|-+$/g, '');
}

export default function rehypeWorkHeadingIds() {
  return (tree, file) => {
    const path = (file?.path || file?.history?.[0] || '').replace(/\\/g, '/');
    if (!path.includes('/content/work/')) return;
    const base = path.split('/').pop().replace(/\.[^.]+$/, '');
    walk(tree, (node) => {
      if (node.type !== 'element' || !HEADING.test(node.tagName)) return;
      node.properties = node.properties || {};
      const slug = slugify(textOf(node));
      node.properties.id = slug ? `${base}-${slug}` : base;
      // Demote case-body `h2` to `h4` so the single /work page keeps a valid
      // outline: h1 (page) > h2 (industry) > h3 (case) > h4 (case sections).
      // The id is set above, so the anchor keeps working after the rewrite.
      if (node.tagName === 'h2') node.tagName = 'h4';
    });
  };
}
