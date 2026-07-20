export type Pillar = { title: string; items: string[] };

export const profile = {
  name: 'Enver Cetin',
  claim: ['I build AI that actually works.', 'Not in labs. Not in theory.'],
  role: { en: 'Director AI, Ciklum · Munich', de: 'Director AI, Ciklum · München' },
  email: 'mail@envercetin.de', // verify with Enver before launch
  linkedin: 'https://www.linkedin.com/in/enver-cetin',
  github: 'https://github.com/cetine',
  expertise: {
    en: [
      { title: 'AI Strategy & Transformation', items: ['Enterprise AI strategy & operating models', 'AI governance & roadmaps', 'Use-case frameworks & CoE structures'] },
      { title: 'Agentic AI & LLM Engineering', items: ['Multi-agent orchestration (LangGraph, CrewAI, SK)', 'RAG & enterprise data integration', 'LLM cost-performance modeling'] },
      { title: 'Enterprise Architecture & Delivery', items: ['AI-first integration architectures', 'Event-driven automation', 'API / ERP / DMS integration'] },
      { title: 'Applied Automation', items: ['Computer vision in production', 'Process automation at scale', 'From RPA to agentic systems'] },
      { title: 'Industries', items: ['Banking & financial services', 'Manufacturing & logistics', 'Energy, construction, real estate'] },
    ],
    de: [
      { title: 'AI-Strategie & Transformation', items: ['Enterprise-AI-Strategie & Operating Models', 'AI-Governance & Roadmaps', 'Use-Case-Frameworks & CoE-Strukturen'] },
      { title: 'Agentic AI & LLM Engineering', items: ['Multi-Agent-Orchestrierung (LangGraph, CrewAI, SK)', 'RAG & Enterprise-Datenintegration', 'LLM-Kosten-Leistungs-Modellierung'] },
      { title: 'Enterprise-Architektur & Delivery', items: ['AI-first Integrationsarchitekturen', 'Event-getriebene Automatisierung', 'API- / ERP- / DMS-Integration'] },
      { title: 'Angewandte Automatisierung', items: ['Computer Vision in der Produktion', 'Prozessautomatisierung im großen Maßstab', 'Von RPA zu agentischen Systemen'] },
      { title: 'Branchen', items: ['Banken & Finanzdienstleister', 'Fertigung & Logistik', 'Energie, Bau, Immobilien'] },
    ],
  },
} as const;

// Career timeline: ported 1:1 from legacy/profile.ts careerHighlights,
// with the Ciklum entry split into "Director | AI (…– Present)" and the
// prior "Senior Manager | AI" period — exact dates to be confirmed by Enver.
export { careerHighlights, volunteerRoles } from '../../legacy/profile';
