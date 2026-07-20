import { test, expect } from '@playwright/test';

const pages = ['/', '/work', '/writing', '/ventures', '/about', '/contact', '/de', '/de/work', '/de/writing', '/de/ventures', '/de/about', '/de/contact'];

for (const path of pages) {
  test(`no horizontal scroll + meta on ${path}`, async ({ page }) => {
    await page.goto(path);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow).toBeLessThanOrEqual(1);
    expect(await page.locator('meta[name="description"]').getAttribute('content')).toBeTruthy();
    expect(await page.locator('link[rel="canonical"]').count()).toBe(1);
    expect(await page.locator('link[rel="alternate"][hreflang]').count()).toBe(3);
    const lang = await page.locator('html').getAttribute('lang');
    expect(lang).toBe(path.startsWith('/de') ? 'de' : 'en');
  });
}

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

test('search opens and finds a case', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop palette');
  await page.goto('/');
  // Search palette is a client:idle island; its keydown listener attaches after
  // hydration, so retry the shortcut until the palette actually opens.
  await expect(async () => {
    await page.keyboard.press(process.platform === 'darwin' ? 'Meta+k' : 'Control+k');
    await expect(page.getByPlaceholder('Search…')).toBeVisible({ timeout: 500 });
  }).toPass({ timeout: 10_000 });
  await page.getByPlaceholder('Search…').fill('fraud');
  await expect(page.locator('a[href*="/work"]').first()).toBeVisible({ timeout: 5000 });
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
