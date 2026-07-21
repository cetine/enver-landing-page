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
      en: 'Abstract transaction-network diagram for financial services engagements',
      de: 'Abstraktes Transaktionsnetz-Diagramm für Financial-Services-Projekte',
    },
  },
  'Automotive & Manufacturing': {
    anchor: 'automotive-manufacturing',
    alt: {
      en: 'Isometric assembly-line diagram for automotive and manufacturing engagements',
      de: 'Isometrisches Fertigungslinien-Diagramm für Automotive- und Fertigungsprojekte',
    },
  },
  'Logistics & Supply Chain': {
    anchor: 'logistics-supply-chain',
    alt: {
      en: 'Abstract route-map diagram for logistics and supply-chain engagements',
      de: 'Abstraktes Routen-Diagramm für Logistik- und Supply-Chain-Projekte',
    },
  },
  'EPCM & Construction': {
    anchor: 'epcm-construction',
    alt: {
      en: 'Isometric building-wireframe diagram for EPCM and construction engagements',
      de: 'Isometrisches Gebäude-Drahtmodell für EPCM- und Bauprojekte',
    },
  },
  'Strategic AI & Enterprise': {
    anchor: 'strategic-ai-enterprise',
    alt: {
      en: 'Concentric operating-model diagram for strategic AI and enterprise engagements',
      de: 'Konzentrisches Operating-Model-Diagramm für strategische AI- und Enterprise-Projekte',
    },
  },
};
