import { profile } from '../data/profile';

const SITE = 'https://envercetin.de';

export function pageTitle(title?: string): string {
  return title ? `${title} · ${profile.name}` : `${profile.name} · Director AI`;
}

export function personJsonLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name: profile.name,
    jobTitle: 'Director AI',
    worksFor: { '@type': 'Organization', name: 'Ciklum' },
    url: SITE,
    sameAs: [profile.linkedin, profile.github],
  };
}

export function websiteJsonLd() {
  return { '@context': 'https://schema.org', '@type': 'WebSite', name: profile.name, url: SITE };
}

export function articleJsonLd(a: { title: string; description: string; date: Date; url: string; lang: string }) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: a.title,
    description: a.description,
    datePublished: a.date.toISOString().slice(0, 10),
    inLanguage: a.lang,
    url: a.url,
    author: { '@type': 'Person', name: profile.name, url: SITE },
  };
}
