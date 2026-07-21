import { ui } from './ui';

export type Locale = 'en' | 'de';
export const locales: Locale[] = ['en', 'de'];

export function getLocaleFromPath(pathname: string): Locale {
  return pathname === '/de' || pathname.startsWith('/de/') ? 'de' : 'en';
}

export function localizePath(enRootPath: string, locale: Locale): string {
  const clean = enRootPath.startsWith('/') ? enRootPath : `/${enRootPath}`;
  if (locale === 'en') return clean;
  return clean === '/' ? '/de' : `/de${clean}`;
}

export function alternatePath(pathname: string): string {
  if (getLocaleFromPath(pathname) === 'de') {
    const rest = pathname === '/de' ? '/' : pathname.slice(3);
    return rest;
  }
  return localizePath(pathname, 'de');
}

export function t(locale: Locale) {
  return (key: string): string =>
    (ui[locale] as Record<string, string>)[key] ?? (ui.en as Record<string, string>)[key] ?? key;
}
