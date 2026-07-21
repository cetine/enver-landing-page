import type { ImageMetadata } from 'astro';

// Standard (16:9) plates — dark + light
import p01 from '../assets/work/plate-01-bfsi.png';
import p01Light from '../assets/work/plate-01-bfsi-light.png';
import p02 from '../assets/work/plate-02-automotive.png';
import p02Light from '../assets/work/plate-02-automotive-light.png';
import p03 from '../assets/work/plate-03-logistics.png';
import p03Light from '../assets/work/plate-03-logistics-light.png';
import p04 from '../assets/work/plate-04-construction.png';
import p04Light from '../assets/work/plate-04-construction-light.png';
import p05 from '../assets/work/plate-05-strategic.png';
import p05Light from '../assets/work/plate-05-strategic-light.png';

// Wide (3840×1080, label-integrated) plates — dark + light
import p01Wide from '../assets/work/plate-01-bfsi-wide.png';
import p01WideLight from '../assets/work/plate-01-bfsi-wide-light.png';
import p02Wide from '../assets/work/plate-02-automotive-wide.png';
import p02WideLight from '../assets/work/plate-02-automotive-wide-light.png';
import p03Wide from '../assets/work/plate-03-logistics-wide.png';
import p03WideLight from '../assets/work/plate-03-logistics-wide-light.png';
import p04Wide from '../assets/work/plate-04-construction-wide.png';
import p04WideLight from '../assets/work/plate-04-construction-wide-light.png';
import p05Wide from '../assets/work/plate-05-strategic-wide.png';
import p05WideLight from '../assets/work/plate-05-strategic-wide-light.png';

export interface ThemeSet {
  dark: ImageMetadata;
  light: ImageMetadata;
}

export type PlateFormat = 'standard' | 'wide';

export interface WorkArt {
  images: Record<PlateFormat, ThemeSet>;
  anchor: string;
  alt: { en: string; de: string };
}

// Keyed by the exact `industry` frontmatter string. EN and DE case files share
// the same industry values, so one key per industry serves both locales.
export const workArt: Record<string, WorkArt> = {
  BFSI: {
    images: {
      standard: { dark: p01, light: p01Light },
      wide: { dark: p01Wide, light: p01WideLight },
    },
    anchor: 'bfsi',
    alt: {
      en: 'Abstract transaction-network diagram — financial services engagements',
      de: 'Abstraktes Transaktionsnetz-Diagramm — Financial-Services-Projekte',
    },
  },
  'Automotive & Manufacturing': {
    images: {
      standard: { dark: p02, light: p02Light },
      wide: { dark: p02Wide, light: p02WideLight },
    },
    anchor: 'automotive-manufacturing',
    alt: {
      en: 'Isometric assembly-line diagram — automotive and manufacturing engagements',
      de: 'Isometrisches Fertigungslinien-Diagramm — Automotive- und Fertigungsprojekte',
    },
  },
  'Logistics & Supply Chain': {
    images: {
      standard: { dark: p03, light: p03Light },
      wide: { dark: p03Wide, light: p03WideLight },
    },
    anchor: 'logistics-supply-chain',
    alt: {
      en: 'Abstract route-map diagram — logistics and supply-chain engagements',
      de: 'Abstraktes Routen-Diagramm — Logistik- und Supply-Chain-Projekte',
    },
  },
  'EPCM & Construction': {
    images: {
      standard: { dark: p04, light: p04Light },
      wide: { dark: p04Wide, light: p04WideLight },
    },
    anchor: 'epcm-construction',
    alt: {
      en: 'Isometric building-wireframe diagram — EPCM and construction engagements',
      de: 'Isometrisches Gebäude-Drahtmodell — EPCM- und Bauprojekte',
    },
  },
  'Strategic AI & Enterprise': {
    images: {
      standard: { dark: p05, light: p05Light },
      wide: { dark: p05Wide, light: p05WideLight },
    },
    anchor: 'strategic-ai-enterprise',
    alt: {
      en: 'Concentric operating-model diagram — strategic AI and enterprise engagements',
      de: 'Konzentrisches Operating-Model-Diagramm — strategische AI- und Enterprise-Projekte',
    },
  },
};
