import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown } from 'lucide-react';

type WorkType = 'Strategy' | 'Architecture' | 'Engineering';

type KPI = {
    label: string;
    value: string;
};

type Tool = {
    name: string;
    src: string;
};

type Initiative = {
    title: string;
    challenge: string;
    workType: WorkType;
    results: {
        summary: string;
        kpis: KPI[];
    };
    tags: string[];
    tools: Tool[];
};

type IndustryGroup = {
    industry: string;
    items: Initiative[];
};

const initiatives: IndustryGroup[] = [
    {
        industry: "Automotive & Manufacturing",
        items: [
            {
                title: "Technician Support Agentic Swarm",
                challenge: "High complexities in modern vehicle electronics led to a surge in diagnostic time, with technicians spending hours sifting through fragmented PDF manuals. This informational bottleneck resulted in missed SLA targets and a significant drop in first-time fix rates, affecting dealership profitability.",
                workType: "Architecture",
                results: {
                    summary: "Architected a Multi-Agent System (Intake, Diagnostic, Repair) automating root cause analysis. The system orchestrates 3 specialized agents to retrieve knowledge from 22k+ manuals and guides technicians step-by-step. This reduced the average handle time by 66% and directly improved first-time fix rates.",
                    kpis: [
                        { value: "£1.3m", label: "Value Created" },
                        { value: "<1 hr", label: "Repair SLA" },
                        { value: "-66%", label: "Avg Handle Time" }
                    ]
                },
                tags: ["Multi-Agent System", "Knowledge Retrieval", "Service Ops"],
                tools: [
                    { name: "Azure", src: "/images/logos/microsoft-azure-logo.png" },
                    { name: "CrewAI", src: "/images/logos/CrewAI.png" },
                    { name: "Semantic Kernel", src: "/images/logos/SemanticKernel.png" },
                ]
            },
            {
                title: "Smart Factory Digital Twin",
                challenge: "Defects in the high-speed assembly line were often identified only at the end-of-line quality check, leading to costly teardowns and material waste. The existing manual inspection process was too slow to catch intermittent issues, resulting in compounded inefficiencies across the production shift.",
                workType: "Engineering",
                results: {
                    summary: "Implemented computer vision edge models for real-time defect detection feeding back to PLCs. By deploying these models at the edge, we achieved sub-millisecond latency for immediate quality control decisions. This proactive loop reduced overall material scrap by 15% and significantly boosted line efficiency.",
                    kpis: [
                        { value: "15%", label: "Scrap Savings" },
                        { value: "99.9%", label: "Defect Detection" },
                        { value: "+20%", label: "OEE Uplift" }
                    ]
                },
                tags: ["Industrial IoT", "Computer Vision", "Edge AI"],
                tools: [
                    { name: "AWS", src: "/images/logos/AWS.svg.png" },
                    { name: "HuggingFace", src: "/images/logos/Huggingface.svg" },
                    { name: "Anthropic", src: "/images/logos/Anthropic.png" },
                ]
            }
        ]
    },
    {
        industry: "EPCM & Construction",
        items: [
            {
                title: "Construction Research Copilots",
                challenge: "The research team was overwhelmed by the sheer volume of global construction projects, missing critical market signals due to manual data entry limitations. The inability to track real-time changes across thousands of council websites meant opportunities were lost and client reports were often outdated by the time of delivery.",
                workType: "Architecture",
                results: {
                    summary: "Deployed a Supervisor AI Copilot orchestrating 4 specialized Sub-Copilots for scraping and analysis. This system autonomously monitors over 4,000 global projects, extracting key market intelligence updates daily. The automation replaced manual tracking, saving 17 FTEs annually while delivering 10x faster insights.",
                    kpis: [
                        { value: "17 FTE", label: "Annual Savings" },
                        { value: "4,000+", label: "Projects Tracked" },
                        { value: "10x", label: "Faster Analysis" }
                    ]
                },
                tags: ["Agent Orchestration", "Web Scraping", "Market Intelligence"],
                tools: [
                    { name: "Azure", src: "/images/logos/microsoft-azure-logo.png" },
                    { name: "LangChain", src: "/images/logos/LangChain_Logo.svg.png" },
                    { name: "Semantic Kernel", src: "/images/logos/SemanticKernel.png" },
                ]
            },
            {
                title: "Generative BIM Compliance",
                challenge: "Manually cross-referencing complex Building Information Models against evolving local safety codes was an error-prone and labor-intensive process. Engineers spent weeks on visual inspections, creating a severe bottleneck in the design phase and increasing the risk of costly retrofits during construction.",
                workType: "Engineering",
                results: {
                    summary: "Built a geometry-aware AI engine to parse Industry Foundation Classes (IFC) files for auto-compliance. The engine autonomously validates complex building models against rigorous local safety codes in minutes rather than weeks. This drastically accelerated the design phase, achieving 60% faster review cycles with zero compliance misses.",
                    kpis: [
                        { value: "60%", label: "Faster Reviews" },
                        { value: "80%", label: "Auto-Checked" },
                        { value: "0", label: "Compliance Misses" }
                    ]
                },
                tags: ["Generative Design", "BIM/IFC", "Compliance"],
                tools: [
                    { name: "Azure", src: "/images/logos/microsoft-azure-logo.png" },
                    { name: "Cohere", src: "/images/logos/Cohere.png" },
                    { name: "Semantic Kernel", src: "/images/logos/SemanticKernel.png" },
                ]
            }
        ]
    },
    {
        industry: "Logistics & Supply Chain",
        items: [
            {
                title: "Intelligent Warehouse Slotting & Flow",
                challenge: "Static warehouse layouts and manual slotting rules caused chronic inefficiencies, with pickers walking up to 12 km per shift due to poor product placement. Seasonal demand spikes overwhelmed the existing planning process, leading to stockouts in high-velocity SKUs while slow movers occupied prime warehouse real estate.",
                workType: "Engineering",
                results: {
                    summary: "Built an AI-driven dynamic slotting engine that continuously re-optimizes product placement based on real-time order patterns and demand forecasts. The system ingests WMS data, models picker travel paths, and generates overnight rebalancing plans. This cut average pick-path distances by 35% and increased warehouse throughput by 22% without additional headcount.",
                    kpis: [
                        { value: "-35%", label: "Pick-Path Distance" },
                        { value: "+22%", label: "Throughput" },
                        { value: "+18%", label: "Space Utilization" }
                    ]
                },
                tags: ["Warehouse AI", "Demand Forecasting", "Operations Research"],
                tools: [
                    { name: "AWS", src: "/images/logos/AWS.svg.png" },
                    { name: "Databricks", src: "/images/logos/Databricks_Logo.png" },
                    { name: "HuggingFace", src: "/images/logos/Huggingface.svg" },
                ]
            },
            {
                title: "Predictive Fleet Dispatch & Delivery",
                challenge: "Route planning relied on dispatcher experience and static schedules, leaving significant fleet capacity underutilized. Driver availability, traffic patterns, and delivery time-windows were managed in disconnected systems, resulting in frequent missed SLAs and excessive empty-mile runs that inflated fuel costs across the network.",
                workType: "Architecture",
                results: {
                    summary: "Architected a predictive dispatch platform combining real-time telematics, weather, and traffic data with an AI optimization core. The system dynamically assigns loads to drivers based on predicted ETAs, hours-of-service compliance, and vehicle capacity — rebalancing routes in real-time as conditions change. This improved on-time delivery from 82% to 96% and cut empty miles by 28%.",
                    kpis: [
                        { value: "96%", label: "On-Time Delivery" },
                        { value: "-28%", label: "Empty Miles" },
                        { value: "€1.8m", label: "Annual Savings" }
                    ]
                },
                tags: ["Fleet Optimization", "Predictive Logistics", "Real-Time Dispatch"],
                tools: [
                    { name: "Azure", src: "/images/logos/microsoft-azure-logo.png" },
                    { name: "CrewAI", src: "/images/logos/CrewAI.png" },
                    { name: "Semantic Kernel", src: "/images/logos/SemanticKernel.png" },
                ]
            }
        ]
    },
    {
        industry: "BFSI",
        items: [
            {
                title: "Automated KYC & Enhanced Due Diligence",
                challenge: "Onboarding new corporate clients required analysts to manually review hundreds of pages of identity documents, ownership structures, and sanctions lists. The average cycle stretched to 21 days, with frequent rework due to inconsistent risk assessments across regional teams — creating both regulatory exposure and client frustration.",
                workType: "Architecture",
                results: {
                    summary: "Architected a multi-agent KYC pipeline that autonomously extracts entity data from submitted documents, resolves Ultimate Beneficial Ownership (UBO) chains, and cross-references against global sanctions and PEP databases in real-time. A human-in-the-loop review stage flags edge cases while auto-approving low-risk profiles. This reduced average onboarding from 21 days to 4 days with zero regulatory findings in the subsequent audit cycle.",
                    kpis: [
                        { value: "-81%", label: "Onboarding Time" },
                        { value: "100%", label: "Audit Compliance" },
                        { value: "5x", label: "Analyst Throughput" }
                    ]
                },
                tags: ["KYC Automation", "Regulatory AI", "Entity Resolution"],
                tools: [
                    { name: "Azure", src: "/images/logos/microsoft-azure-logo.png" },
                    { name: "OpenAI", src: "/images/logos/OpenAI_Logo.svg.png" },
                    { name: "Semantic Kernel", src: "/images/logos/SemanticKernel.png" },
                ]
            },
            {
                title: "Adaptive Fraud Detection Network",
                challenge: "The legacy rule-based fraud engine generated an overwhelming volume of false positives — over 95% of flagged transactions were legitimate. Investigators wasted hours triaging benign alerts while sophisticated fraud rings exploiting novel patterns slipped through undetected. Annual fraud losses had risen 40% year-over-year despite increasing team size.",
                workType: "Engineering",
                results: {
                    summary: "Implemented a hybrid fraud detection system combining graph neural networks for relationship analysis with real-time anomaly scoring on transaction streams. The system identifies coordinated fraud rings by mapping entity relationships across accounts, devices, and geolocations. An AI investigation copilot auto-generates case summaries and recommends actions, cutting mean investigation time by 70%.",
                    kpis: [
                        { value: "-78%", label: "False Positives" },
                        { value: "3.2x", label: "Fraud Caught" },
                        { value: "-70%", label: "Investigation Time" }
                    ]
                },
                tags: ["Fraud Analytics", "Graph AI", "Real-Time Scoring"],
                tools: [
                    { name: "AWS", src: "/images/logos/AWS.svg.png" },
                    { name: "Databricks", src: "/images/logos/Databricks_Logo.png" },
                    { name: "Anthropic", src: "/images/logos/Anthropic.png" },
                ]
            }
        ]
    },
    {
        industry: "Strategic AI & Enterprise",
        items: [
            {
                title: "VP-Level AI Academy",
                challenge: "Despite having access to top-tier AI tools, the leadership team lacked the strategic framework to integrate Generative AI into their core product roadmap. This knowledge gap stalled innovation, as decision-makers struggled to identify high-value use cases that went beyond simple efficiency gains.",
                workType: "Strategy",
                results: {
                    summary: "Designed 'GenAI in Product' executive program, coaching CXOs on roadmap development. Through a series of high-impact workshops, we bridged the gap between technical capability and business strategy for over 40+ leaders. The program successfully catalyzed the launch of 23 high-value use cases, serving as a blueprint for enterprise-wide adoption.",
                    kpis: [
                        { value: "40+", label: "Execs Upskilled" },
                        { value: "23", label: "Use Cases Launched" },
                        { value: "92%", label: "Program NPS" }
                    ]
                },
                tags: ["Executive Strategy", "Change Management", "AI Adoption"],
                tools: [
                    { name: "Databricks", src: "/images/logos/Databricks_Logo.png" },
                    { name: "AWS", src: "/images/logos/AWS.svg.png" },
                    { name: "Anthropic", src: "/images/logos/Anthropic.png" },
                ]
            },
            {
                title: "Enterprise RAG Backbone",
                challenge: "Advisors were wasting valuable client-facing time searching through a sprawling, unorganized repository of 10,000+ policy documents. The lack of a unified search engine led to inconsistent advice and compliance risks, as outdated or incorrect information was frequently retrieved during critical consultations.",
                workType: "Architecture",
                results: {
                    summary: "Built a custom RAG Agent with strict citation guardrails and graph-based retrieval. This architecture unified access to 10,000+ siloed policy documents, ensuring every answer is backed by verifiable sources. The solution reduced support ticket volume by 45% while maintaining 100% compliance accuracy.",
                    kpis: [
                        { value: "80%", label: "Faster Retrieval" },
                        { value: "100%", label: "Policy Accuracy" },
                        { value: "-45%", label: "Support Tickets" }
                    ]
                },
                tags: ["Secure RAG", "Knowledge Graph", ".NET Core"],
                tools: [
                    { name: "Azure", src: "/images/logos/microsoft-azure-logo.png" },
                    { name: "OpenAI", src: "/images/logos/OpenAI_Logo.svg.png" },
                    { name: "Semantic Kernel", src: "/images/logos/SemanticKernel.png" },
                    { name: "CrewAI", src: "/images/logos/CrewAI.png" },
                ]
            }
        ]
    }
];

const toolSizeOverrides: Record<string, string> = {
    'Azure': 'h-9 max-w-[6rem]',
    'CrewAI': 'h-10 max-w-[6rem]',
    'Semantic Kernel': 'h-12 max-w-[5rem]',
    'Anthropic': 'h-10 max-w-[6rem]',
};

const getWorkTypeColor = (type: WorkType) => {
    switch (type) {
        case 'Strategy': return 'bg-blue-50 text-blue-700 border-blue-200';
        case 'Architecture': return 'bg-emerald-50 text-emerald-700 border-emerald-200';
        case 'Engineering': return 'bg-purple-50 text-purple-700 border-purple-200';
    }
};

export default function ProjectsSection() {
    const [expandedIndustries, setExpandedIndustries] = useState<Set<number>>(new Set());

    const toggleIndustry = (index: number) => {
        setExpandedIndustries(prev => {
            const next = new Set(prev);
            if (next.has(index)) {
                next.delete(index);
            } else {
                next.add(index);
            }
            return next;
        });
    };

    return (
        <section id="projects" className="py-24 bg-slate-50">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <motion.div
                    className="mb-20 text-center"
                    initial={{ opacity: 0, y: 30 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true, margin: '-80px' }}
                    transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
                >
                    <h2 className="text-4xl font-bold text-slate-900 mb-4">Featured AI Initiatives</h2>
                    <p className="text-lg text-slate-600 max-w-2xl mx-auto">
                        Driving enterprise value through high-impact, scalable AI architectures.
                    </p>
                </motion.div>

                <div className="space-y-8">
                    {initiatives.map((group, groupIndex) => (
                        <motion.div
                            key={groupIndex}
                            initial={{ opacity: 0, y: 40 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true, margin: '-100px' }}
                            transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1], delay: groupIndex * 0.08 }}
                        >
                            <button
                                type="button"
                                onClick={() => toggleIndustry(groupIndex)}
                                aria-expanded={expandedIndustries.has(groupIndex)}
                                className="flex items-center w-full mb-8 cursor-pointer group/header"
                            >
                                <h3 className="text-2xl font-bold text-slate-800 border-l-4 border-blue-600 pl-4 group-hover/header:text-blue-700 transition-colors duration-200">
                                    {group.industry}
                                </h3>
                                <div className="h-px bg-slate-200 flex-grow ml-6"></div>
                                <motion.div
                                    animate={{ rotate: expandedIndustries.has(groupIndex) ? 180 : 0 }}
                                    transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
                                    className="ml-4 flex-shrink-0"
                                >
                                    <ChevronDown className="w-6 h-6 text-slate-400 group-hover/header:text-blue-600 transition-colors duration-200" />
                                </motion.div>
                            </button>

                            <AnimatePresence initial={false}>
                                {expandedIndustries.has(groupIndex) && (
                                    <motion.div
                                        key={`grid-${groupIndex}`}
                                        initial={{ height: 0, opacity: 0 }}
                                        animate={{ height: 'auto', opacity: 1 }}
                                        exit={{ height: 0, opacity: 0 }}
                                        transition={{
                                            height: { duration: 0.4, ease: [0.22, 1, 0.36, 1] },
                                            opacity: { duration: 0.3, ease: 'easeInOut' },
                                        }}
                                        className="overflow-hidden"
                                    >
                                        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-6xl mx-auto pb-4">
                                            {group.items.map((project, index) => (
                                                <div
                                                    key={index}
                                                    className="group bg-white rounded-2xl p-8 border border-slate-200 shadow-sm hover:shadow-2xl hover:-translate-y-1 transition-all duration-300 flex flex-col h-full relative overflow-hidden"
                                                >
                                                    <div className={`absolute top-0 left-0 w-1 h-full transition-colors duration-300 ${project.workType === 'Strategy' ? 'bg-blue-500' :
                                                        project.workType === 'Architecture' ? 'bg-emerald-500' :
                                                            'bg-purple-500'
                                                        }`}></div>

                                                    <div className="flex justify-between items-start mb-6 pl-4">
                                                        <h4 className="text-xl font-bold text-slate-900 leading-tight">
                                                            {project.title}
                                                        </h4>
                                                        <span className={`px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wide border ${getWorkTypeColor(project.workType)}`}>
                                                            {project.workType}
                                                        </span>
                                                    </div>

                                                    <div className="space-y-6 flex-grow pl-4">
                                                        <div>
                                                            <div className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">The Challenge</div>
                                                            <p className="text-slate-600 text-sm leading-relaxed">
                                                                {project.challenge}
                                                            </p>
                                                        </div>

                                                        <div>
                                                            <div className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">Impact Delivered</div>
                                                            <p className="text-slate-600 text-sm leading-relaxed text-justify">
                                                                {project.results.summary}
                                                            </p>
                                                        </div>
                                                    </div>

                                                    <div className="mt-8 pt-6 border-t border-slate-100 pl-4">
                                                        <div className="grid grid-cols-3 gap-4 mb-6">
                                                            {project.results.kpis.map((kpi, k) => (
                                                                <div key={k}>
                                                                    <div className="text-xl font-black text-slate-900 mb-1">
                                                                        {kpi.value}
                                                                    </div>
                                                                    <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                                                                        {kpi.label}
                                                                    </div>
                                                                </div>
                                                            ))}
                                                        </div>

                                                        <div className="flex flex-wrap gap-2">
                                                            {project.tags.map((tag) => (
                                                                <span
                                                                    key={tag}
                                                                    className="px-2.5 py-1 bg-slate-50 text-slate-500 text-[10px] font-semibold rounded-md border border-slate-200"
                                                                >
                                                                    {tag}
                                                                </span>
                                                            ))}
                                                        </div>

                                                        <div className="flex items-center gap-4 mt-4 pt-3 border-t border-dashed border-slate-100">
                                                            <span className="text-[9px] font-bold text-slate-300 uppercase tracking-widest shrink-0">Built with</span>
                                                            <div className="flex items-center gap-4">
                                                                {project.tools.map((tool) => (
                                                                    <div
                                                                        key={tool.name}
                                                                        className={`flex items-center justify-center ${toolSizeOverrides[tool.name] || 'h-7 max-w-[5.5rem]'}`}
                                                                        title={tool.name}
                                                                    >
                                                                        <img
                                                                            src={tool.src}
                                                                            alt={tool.name}
                                                                            className="h-full w-auto object-contain"
                                                                        />
                                                                    </div>
                                                                ))}
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </motion.div>
                    ))}
                </div>
            </div>
        </section>
    );
}
