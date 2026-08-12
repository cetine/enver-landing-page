import { test, expect } from '@playwright/test';

// `hreflang` counts en + de + x-default on translated pages. Writing posts are
// English-only, so they must NOT advertise a German counterpart: en + x-default.
const pages: { path: string; hreflang: number }[] = [
  ...['/', '/work', '/writing', '/ventures', '/about', '/contact',
    '/de', '/de/work', '/de/writing', '/de/ventures', '/de/about', '/de/contact',
  ].map((path) => ({ path, hreflang: 3 })),
  // Post pages carry the widest content on the site (the hand-drawn figures), so
  // they are the ones most likely to break the no-horizontal-scroll rule.
  { path: '/writing/gdpr-presidio-llm-privacy', hreflang: 2 },
  { path: '/writing/ai-act-article-50-marking', hreflang: 2 },
];

for (const { path, hreflang } of pages) {
  test(`no horizontal scroll + meta on ${path}`, async ({ page }) => {
    await page.goto(path);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow).toBeLessThanOrEqual(1);
    expect(await page.locator('meta[name="description"]').getAttribute('content')).toBeTruthy();
    expect(await page.locator('link[rel="canonical"]').count()).toBe(1);
    expect(await page.locator('link[rel="alternate"][hreflang]').count()).toBe(hreflang);
    const lang = await page.locator('html').getAttribute('lang');
    expect(lang).toBe(path.startsWith('/de') ? 'de' : 'en');
  });
}

test('language toggle on an English-only post does not dead-end', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop nav');
  // The mirrored path /de/writing/<slug> does not exist, so the toggle has to
  // fall back to the German writing index rather than 404.
  await page.goto('/writing/gdpr-presidio-llm-privacy');
  const [response] = await Promise.all([
    page.waitForNavigation(),
    page.click('a[rel="alternate"]'),
  ]);
  expect(response?.status()).toBe(200);
  await expect(page).toHaveURL(/\/de\/writing$/);
});

test('hero claim is verbatim', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('h1')).toHaveText('I build AI that actually works.');
});

test('theme toggle switches data-theme', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop toggle');
  await page.goto('/');
  await page.click('#theme-toggle');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
});

// Search palette is a client:idle island; its keydown listener attaches after
// hydration, so retry the shortcut until the palette actually opens.
async function openPalette(page: import('@playwright/test').Page) {
  await expect(async () => {
    await page.keyboard.press(process.platform === 'darwin' ? 'Meta+k' : 'Control+k');
    await expect(page.getByPlaceholder('Search…')).toBeVisible({ timeout: 500 });
  }).toPass({ timeout: 10_000 });
}

test('search opens and finds a case', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop palette');
  await page.goto('/');
  await openPalette(page);
  await page.getByPlaceholder('Search…').fill('fraud');
  // Scope to the palette overlay (.fixed) so the nav's own /work link cannot
  // satisfy this assertion — the match must be a real search result.
  await expect(page.locator('.fixed a[href*="/work"]').first()).toBeVisible({ timeout: 5000 });
});

test('search shows no-results for a nonsense query', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop palette');
  await page.goto('/');
  await openPalette(page);
  await page.getByPlaceholder('Search…').fill('zzzznotfound');
  await expect(page.locator('.fixed').getByText('No results.')).toBeVisible({ timeout: 5000 });
  // A query with zero hits must yield no palette result link.
  await expect(page.locator('.fixed a[href*="/work"]')).toHaveCount(0);
});

test('language toggle keeps the page', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop nav');
  await page.goto('/work');
  await page.click('a[rel="alternate"]');
  await expect(page).toHaveURL(/\/de\/work$/);
});

test('contact form validates before send', async ({ page }) => {
  await page.goto('/contact');
  await page.click('button[type="submit"]');
  await expect(page.locator('#form-status')).toContainText(/name|Name/);
});
