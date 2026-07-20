import type { Locale } from '../i18n/routes';

export type WritingMeta = {
  slug: string; locale: Locale; title: string; date: Date; description: string;
  tags: string[]; type: 'post' | 'external'; externalUrl?: string; source?: string;
};

export function filterLocale<T extends { id: string }>(entries: T[], locale: Locale): T[] {
  return entries.filter((e) => e.id.startsWith(`${locale}/`));
}

export function sortByDateDesc<T extends { date: Date }>(items: T[]): T[] {
  return [...items].sort((a, b) => b.date.getTime() - a.date.getTime());
}

export function groupByMonth(items: WritingMeta[], locale: Locale, min = 8) {
  const sorted = sortByDateDesc(items);
  if (sorted.length < min) return { grouped: false, groups: [{ label: '', items: sorted }] };
  const fmt = new Intl.DateTimeFormat(locale === 'de' ? 'de-DE' : 'en-US', { month: 'long' });
  const groups: { label: string; items: WritingMeta[] }[] = [];
  for (const item of sorted) {
    const label = locale === 'de'
      ? `${fmt.format(item.date)} ${item.date.getFullYear()}`
      : `${item.date.getFullYear()} ${fmt.format(item.date)}`;
    const last = groups[groups.length - 1];
    if (last && last.label === label) last.items.push(item);
    else groups.push({ label, items: [item] });
  }
  return { grouped: true, groups };
}

export function readingTimeMinutes(text: string, wpm = 200): number {
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.ceil(words / wpm));
}
