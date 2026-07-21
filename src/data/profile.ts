export type Pillar = { title: string; items: string[] };

export const profile = {
  name: 'Enver Cetin',
  claim: ['I build AI that actually works.', 'Not in labs. Not in theory.'],
  role: { en: 'Director AI, Ciklum · Munich · Working globally', de: 'Director AI, Ciklum · München · Global tätig' },
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
  engagement: {
    en: {
      networks: [
        'Atlantik-Brücke, New Bridge Program alumnus',
        'Deutsch-Britische Gesellschaft, Young Königswinter alumnus',
        'CSU digital affairs lead (Bavaria)',
      ],
      teaching: [
        'AI trainings & executive education for leadership teams',
        'Lecturer for AI & automation at Bots and People',
        'Workshops and keynotes on agentic AI adoption',
      ],
    },
    de: {
      networks: [
        'Atlantik-Brücke, Alumnus des New Bridge Program',
        'Deutsch-Britische Gesellschaft, Young-Königswinter-Alumnus',
        'CSU-Digitalbeauftragter (Bayern)',
      ],
      teaching: [
        'AI-Trainings & Executive Education für Führungsteams',
        'Lecturer für AI & Automatisierung bei Bots and People',
        'Workshops und Keynotes zu Agentic-AI-Adoption',
      ],
    },
  },
} as const;

// Career as a dateless station list (no periods, no summaries). Roles are kept
// per-locale for flexibility even where EN and DE currently match.
export type CareerStation = { company: string; role: { en: string; de: string } };
export const careerStations: CareerStation[] = [
  { company: 'Ciklum', role: { en: 'Senior Manager AI, today Director AI', de: 'Senior Manager AI, heute Director AI' } },
  { company: 'Bots and People', role: { en: 'Lecturer & Coach, AI & Automation', de: 'Lecturer & Coach, AI & Automatisierung' } },
  { company: 'Andreas Schmid Group', role: { en: 'Head of Process & Digital Excellence', de: 'Head of Process & Digital Excellence' } },
  { company: 'Wacker Chemie', role: { en: 'Robotic Process Automation Lead', de: 'Robotic Process Automation Lead' } },
];

export { volunteerRoles } from '../../legacy/profile';
