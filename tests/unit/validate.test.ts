import { describe, it, expect } from 'vitest';
import { validateContact } from '../../src/lib/validate';

describe('validateContact', () => {
  it('accepts a valid submission', () => {
    expect(validateContact({ name: 'A', email: 'a@b.de', message: 'Hello there' }).ok).toBe(true);
  });
  it('rejects bad email and empty fields', () => {
    const r = validateContact({ name: '', email: 'nope', message: '' });
    expect(r.ok).toBe(false);
    expect(Object.keys(r.errors)).toEqual(['name', 'email', 'message']);
  });
});
