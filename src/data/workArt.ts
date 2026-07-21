import type { ImageMetadata } from 'astro';

// Standard (16:9) plates — dark + light. The generator also emits wide
// (label-integrated) variants on disk, but the site currently renders standard
// plates only, so the wide imports are intentionally not wired up here.
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

export interface ThemeSet {
  dark: ImageMetadata;
  light: ImageMetadata;
}

export type PlateFormat = 'standard';

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
    },
    anchor: 'strategic-ai-enterprise',
    alt: {
      en: 'Concentric operating-model diagram — strategic AI and enterprise engagements',
      de: 'Konzentrisches Operating-Model-Diagramm — strategische AI- und Enterprise-Projekte',
    },
  },
};
