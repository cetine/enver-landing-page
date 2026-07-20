import { useCallback, useEffect, useRef, useState } from 'react';

type Result = { url: string; title: string; excerpt: string };
declare global { interface Window { __pagefind?: any } }

export default function SearchPalette({ locale }: { locale: string }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Result[]>([]);
  const [error, setError] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const de = locale === 'de';

  const ensurePagefind = useCallback(async () => {
    if (window.__pagefind) return window.__pagefind;
    try {
      window.__pagefind = await import(/* @vite-ignore */ '/pagefind/pagefind.js');
      await window.__pagefind.options({ excerptLength: 20 });
      setError(false);
      return window.__pagefind;
    } catch {
      setError(true);
      return null;
    }
  }, []);

  useEffect(() => {
    const openFn = () => { setOpen(true); setTimeout(() => inputRef.current?.focus(), 30); };
    const key = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openFn(); }
      if (e.key === 'Escape') setOpen(false);
    };
    document.getElementById('open-search')?.addEventListener('click', openFn);
    document.getElementById('open-search-mobile')?.addEventListener('click', openFn);
    window.addEventListener('keydown', key);
    return () => window.removeEventListener('keydown', key);
  }, []);

  useEffect(() => {
    if (!open || !query.trim()) { setResults([]); return; }
    let cancelled = false;
    (async () => {
      const pf = await ensurePagefind();
      if (!pf) return;
      const search = await pf.search(query);
      // Fetch a wider window, then filter by locale BEFORE slicing so a page of
      // other-locale hits can't crowd out same-locale results (no lost backfill).
      const datas = await Promise.all(search.results.slice(0, 24).map((r: any) => r.data()));
      if (!cancelled) {
        const inLocale = (d: any) => {
          const isDe = d.url === '/de' || d.url.startsWith('/de/');
          return de ? isDe : !isDe;
        };
        setResults(datas
          .filter(inLocale)
          .slice(0, 8)
          .map((d: any) => ({ url: d.url, title: d.meta?.title ?? d.url, excerpt: d.excerpt })));
      }
    })();
    return () => { cancelled = true; };
  }, [query, open, de, ensurePagefind]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 p-4 pt-[12vh]" onClick={() => setOpen(false)}>
      <div className="mx-auto max-w-xl rounded-lg border border-line bg-bg shadow-xl" onClick={(e) => e.stopPropagation()}>
        <input
          ref={inputRef}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={de ? 'Suchen…' : 'Search…'}
          className="w-full border-b border-line bg-transparent px-4 py-3 text-[15px] text-fg outline-none"
          aria-label={de ? 'Suche' : 'Search'}
        />
        <div className="max-h-[50vh] overflow-y-auto p-2">
          {error && <p className="p-3 text-[13px] text-muted">{de ? 'Suche ist im Dev-Modus nicht verfügbar (erst nach Build).' : 'Search unavailable in dev mode (available after build).'}</p>}
          {!error && query && results.length === 0 && <p className="p-3 text-[13px] text-muted">{de ? 'Keine Treffer.' : 'No results.'}</p>}
          {results.map((r) => (
            <a key={r.url} href={r.url} className="block rounded p-3 hover:bg-accent-soft">
              <p className="text-[14px] font-medium text-fg">{r.title}</p>
              <p className="mt-0.5 text-[12px] text-muted" dangerouslySetInnerHTML={{ __html: r.excerpt }} />
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
