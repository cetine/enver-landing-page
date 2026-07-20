export interface Profile {
    name: string;
    primaryTitle: string;
    secondaryTitle: string;
    tagline: string;
    location: string;
    primaryCTA: string;
    about: string[];
}

export const profile: Profile = {
    name: "Enver Cetin",
    primaryTitle: "Senior Manager, AI",
    secondaryTitle: "Ciklum",
    tagline: "AI Leader & Architect | Automating Enterprise Value at Scale",
    location: "Munich, Germany",
    primaryCTA: "View Career Journey",
    about: [
        "I build AI that actually works. Not in labs. Not in theory. But inside the German Mittelstand and Fortune 500 companies that run the world’s supply chains, finance, and industries.",
        "I help organizations move from AI hype to real business value. I lead programs across the globe that bring AI, agentic systems, and automation into daily operations. My focus is on designing and delivering AI-first architectures that unlock efficiency, resilience, and new opportunities.",
        "I’m especially passionate about the shift from traditional automation to agentic AI systems that reason, adapt, and integrate seamlessly with enterprise data and processes.",
        "Beyond my work with enterprises, I contribute to digital initiatives for the largest political party in Germany (CSU, Bavaria) and stay active in international US-German dialogue through Atlantik-Brücke’s Fellowship. This mix of business, politics, and thought leadership allows me to bridge technology with strategy, regulation, and society.",
        "If you’re interested in practical AI adoption, digital strategy, or just want to exchange thoughts on the future of intelligent systems 👉 let’s connect."
    ]
};

export interface CareerHighlight {
    role: string;
    company: string;
    period: string;
    location: string;
    summary: string;
    bullets: string[];
}

export const careerHighlights: CareerHighlight[] = [
    {
        role: "Senior Manager | AI",
        company: "Ciklum",
        period: "Jun 2023 – Present",
        location: "London, GB / Munich, DE",
        summary: "Responsible for designing and executing AI-driven transformation programs for global enterprise clients across industries such as manufacturing, infrastructure, energy, industrial services, real estate, and financial services. My work focuses on AI, automation, Data Engineering and production-ready AI agents. Operating at the intersection of strategy, technology and delivery to generate measurable impact.",
        bullets: [
            "Leading initiatives that embed large language models (LLMs) into core operations, develop scalable GenAI copilots, and establish enterprise-wide AI foundations.",
            "Development and execution of enterprise AI strategies, including operating models, governance, and roadmap design.",
            "Delivery of AI-powered solutions combining proprietary data with GPT, Claude, and open-source foundation models.",
            "Designing and implementing prototypes and PoCs that connect AI services with existing systems (APIs, REST, databases, DMS, ERP).",
            "Building integration and data architectures that enable scalable automation (unified data models, event-driven workflows, workflow orchestration).",
            "Enablement of business functions through AI use case frameworks, workshops, and internal AI and automation Center of Excellence structures.",
            "Deep expertise in LLM orchestration, autonomous agent frameworks, AI/automation economics, cost-performance modeling, and enterprise-grade AI governance."
        ]
    },
    {
        role: "Head | Process & Digital Excellence",
        company: "Andreas Schmid Group",
        period: "Jul 2022 – Jun 2023",
        location: "Augsburg, DE",
        summary: "As Head of Process & Digital Excellence, I was responsible for shaping the company's digital transformation agenda and ensuring operational excellence across logistics and supply chain services. My role combined process optimization with the introduction of automation and AI to create measurable business impact.",
        bullets: [
            "Streamlined workflows in finance, procurement, and core logistics processes, reducing manual effort and error rates.",
            "Applied analytics to demand planning, fleet management, and truck utilization to boost efficiency and service reliability.",
            "Re-designed end-to-end processes to cut lead times and increase resilience across the supply chain.",
            "Connected digital strategy with operational execution, building the foundation for a more data-driven, future-ready logistics organization."
        ]
    },
    {
        role: "Manager | Process Automation",
        company: "Andreas Schmid Group",
        period: "Apr 2021 – Jun 2022",
        location: "Augsburg, DE",
        summary: "Founded the Center of Analytics & Process Automation as a central innovation platform.",
        bullets: [
            "Introduced AI-based solutions for process automation, achieving annual savings of >€250,000.",
            "Established scalable standards to improve process quality and efficiency."
        ]
    },
    {
        role: "Lecturer & Coach | AI & Automation",
        company: "Bots and People",
        period: "2020 – Present",
        location: "Remote",
        summary: "At Bots & People, I design and deliver learning sessions on how organizations can successfully adopt and scale automation and AI. My focus is on equipping professionals with the mindset, tools, and strategies to drive digital transformation.",
        bullets: [
            "Intelligent Automation - moving from task-based RPA to value-driven automation strategies.",
            "Change Management - enabling teams and leaders to embrace transformation and adopt new ways of working.",
            "Generative AI Tools - hands-on guidance on how to use GenAI in daily operations to increase productivity and innovation.",
            "Helping participants not only understand the technology but also learn how to integrate it into real business contexts."
        ]
    },
    {
        role: "IT Engineer | Robotic Process Automation Lead",
        company: "Wacker Chemie AG",
        period: "Jul 2019 – Apr 2021",
        location: "Munich, DE",
        summary: "Integrated RPA models in manufacturing to automate production processes.",
        bullets: [
            "Methodically built the strategic framework for process automation from the ground up.",
            "Implemented RPA projects to reduce downtime in production and maintenance."
        ]
    },
    {
        role: "Dual Student Business Informatics",
        company: "Wacker Chemie AG",
        period: "Aug 2016 – Jul 2019",
        location: "Munich, DE",
        summary: "Foundational experience in business informatics and corporate IT structures alongside academic studies.",
        bullets: []
    }
];

export interface VolunteerRole {
    role: string;
    organization: string;
    period: string;
}

export const volunteerRoles: VolunteerRole[] = [
    { role: "Alumni", organization: "Atlantik-Brücke NBP", period: "Jun 2024 – Present" },
    { role: "Digitalbeauftragter", organization: "Christlich-Soziale Union (CSU)", period: "Mar 2025 – Present" },
    { role: "Alumni", organization: "Young Königswinter", period: "Nov 2025 – Present" },
    { role: "Mentor", organization: "Deutschlandstiftung Integration", period: "Jul 2025 – Present" },
    { role: "Member", organization: "German Council on Foreign Relations (DGAP)", period: "Dec 2024 – Present" },
    { role: "Community Member", organization: "2hearts", period: "Jan 2022 – Present" },
    { role: "Member", organization: "InteGREATer e.V.", period: "Oct 2022 – Present" }
];

export interface Certification {
    name: string;
    issuer: string;
    date: string;
}

export const certifications: Certification[] = [
    { name: "ACE it! Master Certification", issuer: "ACE it!", date: "Feb 2025" },
    { name: "Certified Lean Manager", issuer: "Management Circle AG", date: "Feb 2023" },
    { name: "Automation Strategist", issuer: "Bots and People", date: "2021" },
    { name: "Projektmanager:in", issuer: "LinkedIn", date: "2021" },
    { name: "ITIL Foundation", issuer: "AXELOS", date: "2019" },
    { name: "SAP Certified Associate", issuer: "SAP", date: "2018" }
];

export interface Project {
    name: string;
    role: string;
    timeframe: string;
    description: string;
    impact: string;
    tags: string[];
}

export const projects: Project[] = [
    {
        name: "Global AI Division Setup",
        role: "Senior Manager AI",
        timeframe: "2023 - Present",
        description: "Built a multidisciplinary AI team and R&D enablement module from the ground up for a global organization.",
        impact: "Delivered >€15M in cost savings and productivity gains.",
        tags: ["Strategy", "Team Building", "R&D"]
    },
    {
        name: "Supply Chain AI Optimization",
        role: "Head of Digital Excellence",
        timeframe: "2022 - 2023",
        description: "Implemented AI solutions to optimize transport logistics and warehousing processes.",
        impact: "Reduced delivery times by 10% and increased cost efficiency by 15%.",
        tags: ["Logistics", "AI Optimization", "Efficiency"]
    },
    {
        name: "Center of Analytics & Automation",
        role: "Manager Process Automation",
        timeframe: "2021 - 2022",
        description: "Founded a central innovation hub for analytics and process automation.",
        impact: "Achieved annual savings of >€250k through process automation.",
        tags: ["Innovation", "Automation", "Cost Saving"]
    },
    {
        name: "Manufacturing RPA Integration",
        role: "IT Engineer RPA",
        timeframe: "2019 - 2021",
        description: "Deployed RPA models to automate critical production and maintenance processes.",
        impact: "Significantly reduced production downtime.",
        tags: ["RPA", "Manufacturing", "Process Automation"]
    }
];

export const heroLogos = [
    { name: "OpenAI", src: "/images/logos/OpenAI_Logo.svg.png" },
    { name: "Anthropic", src: "/images/logos/anthropic-logo-11760037905ospzboujoo.webp" },
    { name: "Azure", src: "/images/logos/microsoft-azure-logo.png" },
    { name: "AWS", src: "/images/logos/Amazon_Web_Services_Logo.svg.png" },
    { name: "LangChain", src: "/images/logos/LangChain-Logo.png" },
    { name: "CrewAI", src: "/images/logos/crew-ai-logo-png_seeklogo-619843.png" },
    { name: "Cohere", src: "/images/logos/Cohere_Logo_2023.png" },
    { name: "Databricks", src: "/images/logos/Databricks_Logo.png" },
    { name: "HuggingFace", src: "/images/logos/Hf-logo-with-title.svg" }
];

export const heroKeywords = [
    "AI Strategy",
    "Enterprise Automation",
    "Agentic Systems",
    "Digital Transformation"
];


