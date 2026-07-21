import { describe, it, expect } from 'vitest';
import { getLocaleFromPath, localizePath, alternatePath, t } from '../../src/i18n/routes';
import { ui } from '../../src/i18n/ui';

describe('getLocaleFromPath', () => {
  it('detects de prefix', () => {
    expect(getLocaleFromPath('/de')).toBe('de');
    expect(getLocaleFromPath('/de/writing')).toBe('de');
  });
  it('defaults to en', () => {
    expect(getLocaleFromPath('/')).toBe('en');
    expect(getLocaleFromPath('/writing/foo')).toBe('en');
    expect(getLocaleFromPath('/design')).toBe('en'); // no false 'de' match
  });
});

describe('localizePath', () => {
  it('prefixes de and keeps en at root', () => {
    expect(localizePath('/writing', 'de')).toBe('/de/writing');
    expect(localizePath('/', 'de')).toBe('/de');
    expect(localizePath('/writing', 'en')).toBe('/writing');
  });
});

describe('alternatePath', () => {
  it('round-trips both directions', () => {
    expect(alternatePath('/writing/foo')).toBe('/de/writing/foo');
    expect(alternatePath('/de/writing/foo')).toBe('/writing/foo');
    expect(alternatePath('/')).toBe('/de');
    expect(alternatePath('/de')).toBe('/');
  });
});

describe('t', () => {
  it('returns translated ui strings per locale', () => {
    expect(t('de')('nav.work')).toBe('Projekte');
    expect(t('en')('nav.work')).toBe('Work');
  });
  it('falls back to en for keys missing in de, and to the key when missing everywhere', () => {
    Object.assign(ui.en as Record<string, string>, { 'test.fallback': 'Fallback works' });
    expect(t('de')('test.fallback')).toBe('Fallback works');
    delete (ui.en as Record<string, string>)['test.fallback'];
    expect(t('de')('does.not.exist')).toBe('does.not.exist');
  });
});
