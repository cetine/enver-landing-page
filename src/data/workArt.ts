// Per-industry work-art metadata. The plate artwork itself is a theme-adaptive
// inline SVG (see PlateSvg.astro, which imports src/assets/work/plate-0X.svg);
// this module keeps only the non-visual metadata every consumer shares: the
// in-page anchor and the localized alt/label text.
//
// Keyed by the exact `industry` frontmatter string. EN and DE case files share
// the same industry values, so one key per industry serves both locales.

export interface WorkArt {
  anchor: string;
  alt: { en: string; de: string };
}

export const workArt: Record<string, WorkArt> = {
  BFSI: {
    anchor: 'bfsi',
    alt: {
      en: 'Abstract transaction-network diagram — financial services engagements',
      de: 'Abstraktes Transaktionsnetz-Diagramm — Financial-Services-Projekte',
    },
  },
  'Automotive & Manufacturing': {
    anchor: 'automotive-manufacturing',
    alt: {
      en: 'Isometric assembly-line diagram — automotive and manufacturing engagements',
      de: 'Isometrisches Fertigungslinien-Diagramm — Automotive- und Fertigungsprojekte',
    },
  },
  'Logistics & Supply Chain': {
    anchor: 'logistics-supply-chain',
    alt: {
      en: 'Abstract route-map diagram — logistics and supply-chain engagements',
      de: 'Abstraktes Routen-Diagramm — Logistik- und Supply-Chain-Projekte',
    },
  },
  'EPCM & Construction': {
    anchor: 'epcm-construction',
    alt: {
      en: 'Isometric building-wireframe diagram — EPCM and construction engagements',
      de: 'Isometrisches Gebäude-Drahtmodell — EPCM- und Bauprojekte',
    },
  },
  'Strategic AI & Enterprise': {
    anchor: 'strategic-ai-enterprise',
    alt: {
      en: 'Concentric operating-model diagram — strategic AI and enterprise engagements',
      de: 'Konzentrisches Operating-Model-Diagramm — strategische AI- und Enterprise-Projekte',
    },
  },
};
