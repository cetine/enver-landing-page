import ReactFlow, {
    type Node,
    type Edge,
    Controls,
    Background,
    useNodesState,
    useEdgesState,
    Position,
} from 'reactflow';
import 'reactflow/dist/style.css';
import { motion, useScroll, useTransform } from 'framer-motion';
import { useRef } from 'react';

// --- Palette ---
const C = {
    strategy: '#7c3aed',
    agentic: '#2563eb',
    enterprise: '#059669',
    vision: '#d97706',
    industry: '#e11d48',
    strategyLight: '#ddd6fe',
    agenticLight: '#bfdbfe',
    enterpriseLight: '#a7f3d0',
    visionLight: '#fde68a',
    industryLight: '#fecdd3',
};

// --- Styles ---
const rootStyle: React.CSSProperties = {
    background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
    color: 'white',
    border: 'none',
    borderRadius: '14px',
    padding: '20px 28px',
    width: 320,
    fontSize: '20px',
    fontWeight: 'bold',
    textAlign: 'center',
    boxShadow: '0 25px 50px -12px rgb(0 0 0 / 0.25)',
};

const pillarStyle = (color: string): React.CSSProperties => ({
    background: `${color}10`,
    color: '#1e293b',
    border: `2px solid ${color}`,
    borderRadius: '12px',
    padding: '14px 18px',
    width: 260,
    fontSize: '15px',
    fontWeight: 700,
    textAlign: 'center',
    boxShadow: `0 4px 14px -2px ${color}20`,
});

const leafStyle = (accent: string): React.CSSProperties => ({
    background: 'white',
    color: '#475569',
    border: '1px solid #e2e8f0',
    borderLeft: `3px solid ${accent}`,
    borderRadius: '8px',
    padding: '10px 14px',
    width: 195,
    height: 'auto',
    fontSize: '13px',
    fontWeight: 500,
    textAlign: 'center',
    boxShadow: '0 1px 3px 0 rgb(0 0 0 / 0.05)',
    whiteSpace: 'pre-line',
    lineHeight: '1.4',
});

// --- Layout Constants ---
const PILLAR_Y = 200;
const R1 = 410;
const R2 = 500;
const R3 = 590;

// Pillar centers (x)
const P1 = 210;
const P2 = 640;
const P3 = 1070;
const P4 = 1500;
const P5 = 1930;

// Column offsets from pillar center
const CL = -203; // left column
const CR = 8;    // right column

// --- Nodes ---
const initialNodes: Node[] = [
    // ═══════════ ROOT ═══════════
    {
        id: 'root',
        data: { label: 'Enver Cetin — AI Leader & Architect' },
        position: { x: P3 - 160, y: 0 },
        style: rootStyle,
        sourcePosition: Position.Bottom,
    },

    // ═══════════ PILLAR 1: AI STRATEGY & TRANSFORMATION ═══════════
    {
        id: 'p-strategy',
        data: { label: '🎯 AI Strategy & Transformation' },
        position: { x: P1 - 130, y: PILLAR_Y },
        style: pillarStyle(C.strategy),
        sourcePosition: Position.Bottom,
        targetPosition: Position.Top,
    },
    {
        id: 'l-s1',
        data: { label: 'Fortune 500 &\nMittelstand Advisory' },
        position: { x: P1 + CL, y: R1 },
        style: leafStyle(C.strategy),
        targetPosition: Position.Top,
    },
    {
        id: 'l-s2',
        data: { label: 'AI Operating Models\n& Governance' },
        position: { x: P1 + CR, y: R1 },
        style: leafStyle(C.strategy),
        targetPosition: Position.Top,
    },
    {
        id: 'l-s3',
        data: { label: 'Use Case Frameworks\n& ROI Analysis' },
        position: { x: P1 + CL, y: R2 },
        style: leafStyle(C.strategy),
        targetPosition: Position.Top,
    },
    {
        id: 'l-s4',
        data: { label: 'Change Management\n& Enablement' },
        position: { x: P1 + CR, y: R2 },
        style: leafStyle(C.strategy),
        targetPosition: Position.Top,
    },

    // ═══════════ PILLAR 2: AGENTIC AI & LLM ENGINEERING ═══════════
    {
        id: 'p-agentic',
        data: { label: '🤖 Agentic AI & LLM Engineering' },
        position: { x: P2 - 130, y: PILLAR_Y },
        style: pillarStyle(C.agentic),
        sourcePosition: Position.Bottom,
        targetPosition: Position.Top,
    },
    {
        id: 'l-a1',
        data: { label: 'Multi-Agent Orchestration\n(CrewAI, SK, LangGraph)' },
        position: { x: P2 + CL, y: R1 },
        style: leafStyle(C.agentic),
        targetPosition: Position.Top,
    },
    {
        id: 'l-a2',
        data: { label: 'RAG &\nKnowledge Graphs' },
        position: { x: P2 + CR, y: R1 },
        style: leafStyle(C.agentic),
        targetPosition: Position.Top,
    },
    {
        id: 'l-a3',
        data: { label: 'LLM Ops & Evaluation\n(Arize, LangSmith)' },
        position: { x: P2 + CL, y: R2 },
        style: leafStyle(C.agentic),
        targetPosition: Position.Top,
    },
    {
        id: 'l-a4',
        data: { label: 'Prompt Engineering\n& Function Calling' },
        position: { x: P2 + CR, y: R2 },
        style: leafStyle(C.agentic),
        targetPosition: Position.Top,
    },
    {
        id: 'l-a5',
        data: { label: 'ReAct & Reflection\nPatterns' },
        position: { x: P2 + CL, y: R3 },
        style: leafStyle(C.agentic),
        targetPosition: Position.Top,
    },
    {
        id: 'l-a6',
        data: { label: 'Autonomous\nWorkflows' },
        position: { x: P2 + CR, y: R3 },
        style: leafStyle(C.agentic),
        targetPosition: Position.Top,
    },

    // ═══════════ PILLAR 3: ENTERPRISE ARCHITECTURE & DELIVERY ═══════════
    {
        id: 'p-enterprise',
        data: { label: '🏗️ Enterprise Architecture & Delivery' },
        position: { x: P3 - 130, y: PILLAR_Y },
        style: pillarStyle(C.enterprise),
        sourcePosition: Position.Bottom,
        targetPosition: Position.Top,
    },
    {
        id: 'l-e1',
        data: { label: 'Cloud Platforms\n(Azure, AWS, GCP)' },
        position: { x: P3 + CL, y: R1 },
        style: leafStyle(C.enterprise),
        targetPosition: Position.Top,
    },
    {
        id: 'l-e2',
        data: { label: 'Data Engineering\n(Databricks, Spark)' },
        position: { x: P3 + CR, y: R1 },
        style: leafStyle(C.enterprise),
        targetPosition: Position.Top,
    },
    {
        id: 'l-e3',
        data: { label: 'API & System Integration\n(ERP, DMS, REST)' },
        position: { x: P3 + CL, y: R2 },
        style: leafStyle(C.enterprise),
        targetPosition: Position.Top,
    },
    {
        id: 'l-e4',
        data: { label: 'Event-Driven &\nWorkflow Orchestration' },
        position: { x: P3 + CR, y: R2 },
        style: leafStyle(C.enterprise),
        targetPosition: Position.Top,
    },
    {
        id: 'l-e5',
        data: { label: 'AI Governance\n& Compliance' },
        position: { x: P3 + CL, y: R3 },
        style: leafStyle(C.enterprise),
        targetPosition: Position.Top,
    },
    {
        id: 'l-e6',
        data: { label: 'Scalable Infrastructure\n& MLOps' },
        position: { x: P3 + CR, y: R3 },
        style: leafStyle(C.enterprise),
        targetPosition: Position.Top,
    },

    // ═══════════ PILLAR 4: COMPUTER VISION & AUTOMATION ═══════════
    {
        id: 'p-vision',
        data: { label: '👁️ Computer Vision & Automation' },
        position: { x: P4 - 130, y: PILLAR_Y },
        style: pillarStyle(C.vision),
        sourcePosition: Position.Bottom,
        targetPosition: Position.Top,
    },
    {
        id: 'l-v1',
        data: { label: 'Edge AI &\nReal-Time Inference' },
        position: { x: P4 + CL, y: R1 },
        style: leafStyle(C.vision),
        targetPosition: Position.Top,
    },
    {
        id: 'l-v2',
        data: { label: 'Computer Vision\n& Quality Control' },
        position: { x: P4 + CR, y: R1 },
        style: leafStyle(C.vision),
        targetPosition: Position.Top,
    },
    {
        id: 'l-v3',
        data: { label: 'RPA & Intelligent\nAutomation' },
        position: { x: P4 + CL, y: R2 },
        style: leafStyle(C.vision),
        targetPosition: Position.Top,
    },
    {
        id: 'l-v4',
        data: { label: 'Industrial IoT\n& Digital Twins' },
        position: { x: P4 + CR, y: R2 },
        style: leafStyle(C.vision),
        targetPosition: Position.Top,
    },

    // ═══════════ PILLAR 5: INDUSTRIES & IMPACT ═══════════
    {
        id: 'p-industry',
        data: { label: '🌍 Industries & Impact' },
        position: { x: P5 - 130, y: PILLAR_Y },
        style: pillarStyle(C.industry),
        sourcePosition: Position.Bottom,
        targetPosition: Position.Top,
    },
    {
        id: 'l-i1',
        data: { label: 'Automotive &\nManufacturing' },
        position: { x: P5 + CL, y: R1 },
        style: leafStyle(C.industry),
        targetPosition: Position.Top,
    },
    {
        id: 'l-i2',
        data: { label: 'EPCM &\nConstruction' },
        position: { x: P5 + CR, y: R1 },
        style: leafStyle(C.industry),
        targetPosition: Position.Top,
    },
    {
        id: 'l-i3',
        data: { label: 'Logistics &\nSupply Chain' },
        position: { x: P5 + CL, y: R2 },
        style: leafStyle(C.industry),
        targetPosition: Position.Top,
    },
    {
        id: 'l-i4',
        data: { label: 'Financial Services\n& Energy' },
        position: { x: P5 + CR, y: R2 },
        style: leafStyle(C.industry),
        targetPosition: Position.Top,
    },
    {
        id: 'l-i5',
        data: { label: 'Executive Education\n& Coaching' },
        position: { x: P5 + CL, y: R3 },
        style: leafStyle(C.industry),
        targetPosition: Position.Top,
    },
    {
        id: 'l-i6',
        data: { label: 'Policy &\nDigital Society' },
        position: { x: P5 + CR, y: R3 },
        style: leafStyle(C.industry),
        targetPosition: Position.Top,
    },
];

// --- Edges ---
const pillarEdge = (id: string, target: string, color: string): Edge => ({
    id: `e-root-${id}`,
    source: 'root',
    target,
    type: 'smoothstep',
    animated: true,
    style: { stroke: color, strokeWidth: 2 },
});

const leafEdge = (parent: string, leaf: string, lightColor: string): Edge => ({
    id: `e-${parent}-${leaf}`,
    source: parent,
    target: leaf,
    type: 'default',
    animated: true,
    style: { stroke: lightColor },
});

const initialEdges: Edge[] = [
    // Root → Pillars
    pillarEdge('strategy', 'p-strategy', C.strategy),
    pillarEdge('agentic', 'p-agentic', C.agentic),
    pillarEdge('enterprise', 'p-enterprise', C.enterprise),
    pillarEdge('vision', 'p-vision', C.vision),
    pillarEdge('industry', 'p-industry', C.industry),

    // Strategy → Leaves
    leafEdge('p-strategy', 'l-s1', C.strategyLight),
    leafEdge('p-strategy', 'l-s2', C.strategyLight),
    leafEdge('p-strategy', 'l-s3', C.strategyLight),
    leafEdge('p-strategy', 'l-s4', C.strategyLight),

    // Agentic → Leaves
    leafEdge('p-agentic', 'l-a1', C.agenticLight),
    leafEdge('p-agentic', 'l-a2', C.agenticLight),
    leafEdge('p-agentic', 'l-a3', C.agenticLight),
    leafEdge('p-agentic', 'l-a4', C.agenticLight),
    leafEdge('p-agentic', 'l-a5', C.agenticLight),
    leafEdge('p-agentic', 'l-a6', C.agenticLight),

    // Enterprise → Leaves
    leafEdge('p-enterprise', 'l-e1', C.enterpriseLight),
    leafEdge('p-enterprise', 'l-e2', C.enterpriseLight),
    leafEdge('p-enterprise', 'l-e3', C.enterpriseLight),
    leafEdge('p-enterprise', 'l-e4', C.enterpriseLight),
    leafEdge('p-enterprise', 'l-e5', C.enterpriseLight),
    leafEdge('p-enterprise', 'l-e6', C.enterpriseLight),

    // Vision → Leaves
    leafEdge('p-vision', 'l-v1', C.visionLight),
    leafEdge('p-vision', 'l-v2', C.visionLight),
    leafEdge('p-vision', 'l-v3', C.visionLight),
    leafEdge('p-vision', 'l-v4', C.visionLight),

    // Industry → Leaves
    leafEdge('p-industry', 'l-i1', C.industryLight),
    leafEdge('p-industry', 'l-i2', C.industryLight),
    leafEdge('p-industry', 'l-i3', C.industryLight),
    leafEdge('p-industry', 'l-i4', C.industryLight),
    leafEdge('p-industry', 'l-i5', C.industryLight),
    leafEdge('p-industry', 'l-i6', C.industryLight),

    // Cross-pillar connections (subtle, dashed)
    {
        id: 'x-rag-data',
        source: 'l-a2',
        target: 'l-e2',
        type: 'straight',
        style: { stroke: '#94a3b8', strokeWidth: 1, strokeDasharray: '6 4' },
    },
    {
        id: 'x-auto-rpa',
        source: 'l-a6',
        target: 'l-v3',
        type: 'straight',
        style: { stroke: '#94a3b8', strokeWidth: 1, strokeDasharray: '6 4' },
    },
    {
        id: 'x-change-edu',
        source: 'l-s4',
        target: 'l-i5',
        type: 'straight',
        style: { stroke: '#94a3b8', strokeWidth: 1, strokeDasharray: '6 4' },
    },
];

export default function TechMapReactFlow() {
    const [nodes, , onNodesChange] = useNodesState(initialNodes);
    const [edges, , onEdgesChange] = useEdgesState(initialEdges);
    const sectionRef = useRef<HTMLElement>(null);

    const { scrollYProgress } = useScroll({
        target: sectionRef,
        offset: ['start end', 'end start'],
    });

    // Curtain reveal: clipPath shrinks inward when off-screen, expands to full when in view
    const clipTop = useTransform(scrollYProgress, [0, 0.3], [8, 0]);
    const clipSide = useTransform(scrollYProgress, [0, 0.3], [4, 0]);
    const clipBottom = useTransform(scrollYProgress, [0, 0.3], [8, 0]);

    return (
        <section ref={sectionRef} id="tech-map" className="py-20 bg-slate-50">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <motion.div
                    className="mb-12 text-center"
                    initial={{ opacity: 0, x: -20, filter: 'blur(6px)' }}
                    whileInView={{ opacity: 1, x: 0, filter: 'blur(0px)' }}
                    viewport={{ once: true, margin: '-100px' }}
                    transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
                >
                    <h2 className="text-3xl font-bold text-slate-900">AI & Technology Landscape</h2>
                    <p className="mt-4 text-slate-600 max-w-2xl mx-auto">
                        From strategic advisory to hands-on engineering — how I help enterprises bridge the gap between AI ambition and real-world impact.
                    </p>
                </motion.div>

                <motion.div
                    className="h-[850px] w-full bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden"
                    style={{
                        clipPath: useTransform(
                            [clipTop, clipSide, clipBottom],
                            ([t, s, b]: number[]) => `inset(${t}% ${s}% ${b}% ${s}%)`
                        ),
                    }}
                >
                    <ReactFlow
                        nodes={nodes}
                        edges={edges}
                        onNodesChange={onNodesChange}
                        onEdgesChange={onEdgesChange}
                        fitView
                        fitViewOptions={{ padding: 0.12 }}
                        attributionPosition="bottom-right"
                        minZoom={0.3}
                        maxZoom={1.5}
                    >
                        <Background color="#e2e8f0" gap={16} />
                        <Controls />
                    </ReactFlow>
                </motion.div>
            </div>
        </section>
    );
}
