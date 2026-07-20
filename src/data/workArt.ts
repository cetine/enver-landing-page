import type { ImageMetadata } from 'astro';
import plate01 from '../assets/work/plate-01-bfsi.png';
import plate02 from '../assets/work/plate-02-automotive.png';
import plate03 from '../assets/work/plate-03-logistics.png';
import plate04 from '../assets/work/plate-04-construction.png';
import plate05 from '../assets/work/plate-05-strategic.png';

export interface WorkArt {
  image: ImageMetadata;
  anchor: string;
  alt: { en: string; de: string };
}

// Keyed by the exact `industry` frontmatter string. EN and DE case files share
// the same industry values, so one key per industry serves both locales.
export const workArt: Record<string, WorkArt> = {
  BFSI: {
    image: plate01,
    anchor: 'bfsi',
    alt: {
      en: 'Abstract transaction-network diagram — financial services engagements',
      de: 'Abstraktes Transaktionsnetz-Diagramm — Financial-Services-Projekte',
    },
  },
  'Automotive & Manufacturing': {
    image: plate02,
    anchor: 'automotive-manufacturing',
    alt: {
      en: 'Isometric assembly-line diagram — automotive and manufacturing engagements',
      de: 'Isometrisches Fertigungslinien-Diagramm — Automotive- und Fertigungsprojekte',
    },
  },
  'Logistics & Supply Chain': {
    image: plate03,
    anchor: 'logistics-supply-chain',
    alt: {
      en: 'Abstract route-map diagram — logistics and supply-chain engagements',
      de: 'Abstraktes Routen-Diagramm — Logistik- und Supply-Chain-Projekte',
    },
  },
  'EPCM & Construction': {
    image: plate04,
    anchor: 'epcm-construction',
    alt: {
      en: 'Isometric building-wireframe diagram — EPCM and construction engagements',
      de: 'Isometrisches Gebäude-Drahtmodell — EPCM- und Bauprojekte',
    },
  },
  'Strategic AI & Enterprise': {
    image: plate05,
    anchor: 'strategic-ai-enterprise',
    alt: {
      en: 'Concentric operating-model diagram — strategic AI and enterprise engagements',
      de: 'Konzentrisches Operating-Model-Diagramm — strategische AI- und Enterprise-Projekte',
    },
  },
};
