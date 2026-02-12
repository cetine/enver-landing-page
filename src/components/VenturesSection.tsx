import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Upload,
    FileCheck,
    Brain,
    Shield,
    Zap,
    ExternalLink,
    ArrowRight,
    ArrowLeft,
    Scale,
    BadgeEuro,
} from 'lucide-react';
import { cn } from '../lib/utils';
import MagneticButton from './MagneticButton';

// ── AI Council members ──────────────────────────────────────────────
const aiCouncil = [
    { name: 'Vertragsrecht', emoji: '\u2696\uFE0F', color: '#3b82f6' },
    { name: 'AGB Experte', emoji: '\uD83D\uDCCB', color: '#8b5cf6' },
    { name: 'Miet Profi', emoji: '\uD83C\uDFE0', color: '#06b6d4' },
    { name: 'Arbeitsrecht', emoji: '\uD83D\uDCBC', color: '#f59e0b' },
    { name: 'Risiko Berater', emoji: '\uD83D\uDEE1\uFE0F', color: '#ef4444' },
];

// ── Mock report clauses ─────────────────────────────────────────────
const mockClauses = [
    { clause: 'Mietdauer (Rental Term)', risk: 'green' as const, label: 'Low Risk' },
    { clause: 'K\u00FCndigungsfrist (Notice)', risk: 'yellow' as const, label: 'Review' },
    { clause: 'Nebenkostenklausel', risk: 'red' as const, label: 'High Risk' },
];

// ── Features ────────────────────────────────────────────────────────
const features = [
    {
        icon: Brain,
        title: 'AI Council Framework',
        desc: '5 specialized AI experts cross-validate every clause',
    },
    {
        icon: Shield,
        title: 'DSGVO Compliant',
        desc: 'German servers, SSL encryption, 24h auto-deletion',
    },
    {
        icon: Zap,
        title: 'Under 2 Minutes',
        desc: 'Full contract analysis delivered as a detailed PDF',
    },
    {
        icon: BadgeEuro,
        title: 'Accessible',
        desc: 'One-time EUR 3.99 per analysis, no subscription',
    },
];

// ── Animation config ────────────────────────────────────────────────
const ease = [0.22, 1, 0.36, 1] as const;

const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
        opacity: 1,
        transition: { staggerChildren: 0.12, delayChildren: 0.1 },
    },
};

const itemVariants = {
    hidden: { opacity: 0, y: 24 },
    visible: {
        opacity: 1,
        y: 0,
        transition: { duration: 0.7, ease },
    },
};

// ── Risk color map ──────────────────────────────────────────────────
const riskColors = {
    green: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/20',
    yellow: 'bg-amber-500/15 text-amber-400 border-amber-500/20',
    red: 'bg-red-500/15 text-red-400 border-red-500/20',
};

// ═══════════════════════════════════════════════════════════════════
//  InteractivePreview — the animated walkthrough
// ═══════════════════════════════════════════════════════════════════
function InteractivePreview() {
    const [step, setStep] = useState(0);

    useEffect(() => {
        const timer = setInterval(() => setStep((s) => (s + 1) % 3), 4000);
        return () => clearInterval(timer);
    }, []);

    return (
        <div className="relative rounded-xl bg-slate-950/60 border border-white/[0.06] overflow-hidden shadow-2xl shadow-black/40">
            {/* ── Faux title bar ─────────────────────────────── */}
            <div className="flex items-center gap-1.5 px-4 py-2.5 border-b border-white/[0.06] bg-white/[0.02]">
                <div className="w-2.5 h-2.5 rounded-full bg-[#ff5f57]" />
                <div className="w-2.5 h-2.5 rounded-full bg-[#febc2e]" />
                <div className="w-2.5 h-2.5 rounded-full bg-[#28c840]" />
                <span className="ml-3 text-[11px] text-slate-500 font-mono tracking-wide">
                    vertragsklar.de
                </span>
            </div>

            {/* ── Animated content area ──────────────────────── */}
            <div className="relative h-56 sm:h-64 flex items-center justify-center p-5">
                {/* Ambient glow inside preview */}
                <div className="absolute inset-0 bg-gradient-to-b from-blue-500/[0.03] to-transparent pointer-events-none" />

                <AnimatePresence mode="wait">
                    {step === 0 && <StepUpload key="upload" />}
                    {step === 1 && <StepAnalyze key="analyze" />}
                    {step === 2 && <StepResults key="results" />}
                </AnimatePresence>
            </div>

            {/* ── Step indicators ────────────────────────────── */}
            <div className="flex justify-center items-center gap-2 pb-4">
                {['Upload', 'Analyze', 'Report'].map((label, i) => (
                    <button
                        key={label}
                        onClick={() => setStep(i)}
                        className={cn(
                            'h-1.5 rounded-full transition-all duration-500',
                            i === step
                                ? 'w-8 bg-blue-400'
                                : 'w-2 bg-slate-700 hover:bg-slate-600'
                        )}
                        aria-label={label}
                    />
                ))}
            </div>
        </div>
    );
}

// ── Step 1: Upload ──────────────────────────────────────────────────
function StepUpload() {
    return (
        <motion.div
            initial={{ opacity: 0, y: 28 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16, filter: 'blur(4px)' }}
            transition={{ duration: 0.5, ease }}
            className="flex flex-col items-center gap-5"
        >
            {/* Upload zone */}
            <motion.div
                className="relative w-16 h-16 rounded-2xl border-2 border-dashed border-blue-500/30 flex items-center justify-center"
                animate={{ borderColor: ['rgba(59,130,246,0.3)', 'rgba(59,130,246,0.6)', 'rgba(59,130,246,0.3)'] }}
                transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
            >
                <div className="absolute inset-0 rounded-2xl bg-blue-500/5" />
                <Upload className="w-7 h-7 text-blue-400 relative z-10" />
            </motion.div>

            {/* File info */}
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.4, duration: 0.5 }}
                className="text-center"
            >
                <p className="text-white/90 font-medium text-sm tracking-tight">
                    mietvertrag.pdf
                </p>
                <p className="text-slate-500 text-xs mt-0.5">2.4 MB uploaded</p>
            </motion.div>
        </motion.div>
    );
}

// ── Step 2: AI Council Analyzes ─────────────────────────────────────
function StepAnalyze() {
    return (
        <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0, y: -16, filter: 'blur(4px)' }}
            transition={{ duration: 0.4 }}
            className="flex flex-col items-center gap-4"
        >
            {/* Council nodes */}
            <div className="flex items-center gap-2.5 sm:gap-3">
                {aiCouncil.map((member, i) => (
                    <motion.div
                        key={member.name}
                        initial={{ opacity: 0, scale: 0 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{
                            delay: i * 0.12,
                            duration: 0.45,
                            ease: 'backOut',
                        }}
                        className="relative flex flex-col items-center"
                    >
                        {/* Pulsing ring */}
                        <motion.div
                            className="absolute inset-0 rounded-full"
                            style={{ border: `1.5px solid ${member.color}40` }}
                            animate={{
                                scale: [1, 1.6],
                                opacity: [0.6, 0],
                            }}
                            transition={{
                                duration: 1.8,
                                repeat: Infinity,
                                delay: i * 0.25,
                                ease: 'easeOut',
                            }}
                        />
                        <div
                            className="w-10 h-10 sm:w-11 sm:h-11 rounded-full bg-slate-800/80 border border-white/10 flex items-center justify-center text-base sm:text-lg relative z-10"
                            style={{ boxShadow: `0 0 20px ${member.color}15` }}
                        >
                            {member.emoji}
                        </div>
                        <span className="text-[9px] text-slate-500 mt-1.5 tracking-tight max-w-[52px] text-center leading-tight hidden sm:block">
                            {member.name}
                        </span>
                    </motion.div>
                ))}
            </div>

            {/* Convergence line */}
            <motion.div
                initial={{ scaleY: 0 }}
                animate={{ scaleY: 1 }}
                transition={{ delay: 0.7, duration: 0.35 }}
                className="w-px h-5 bg-gradient-to-b from-blue-400/50 to-transparent origin-top"
            />

            {/* Synthesis node */}
            <motion.div
                initial={{ opacity: 0, scale: 0.7 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.9, duration: 0.5, ease: 'backOut' }}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-500/10 border border-blue-500/20"
            >
                <motion.div
                    className="w-1.5 h-1.5 rounded-full bg-blue-400"
                    animate={{ opacity: [1, 0.3, 1] }}
                    transition={{ duration: 1.2, repeat: Infinity }}
                />
                <p className="text-blue-300 text-xs font-medium tracking-tight">
                    Cross-validating findings...
                </p>
            </motion.div>
        </motion.div>
    );
}

// ── Step 3: Results ─────────────────────────────────────────────────
function StepResults() {
    return (
        <motion.div
            initial={{ opacity: 0, y: 28 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16, filter: 'blur(4px)' }}
            transition={{ duration: 0.5, ease }}
            className="w-full max-w-xs space-y-2.5"
        >
            {/* Report header */}
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="flex items-center gap-2 mb-3"
            >
                <FileCheck className="w-4 h-4 text-emerald-400" />
                <span className="text-white/90 text-sm font-semibold tracking-tight">
                    Analysis Complete
                </span>
                <span className="ml-auto text-[10px] text-slate-500 font-mono">
                    3 / 12 clauses
                </span>
            </motion.div>

            {/* Clause rows */}
            {mockClauses.map((item, i) => (
                <motion.div
                    key={item.clause}
                    initial={{ opacity: 0, x: -18 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.15 + i * 0.18, duration: 0.45, ease }}
                    className="flex items-center justify-between px-3 py-2 rounded-lg bg-white/[0.03] border border-white/[0.05]"
                >
                    <span className="text-slate-300 text-[11px] sm:text-xs truncate mr-3">
                        {item.clause}
                    </span>
                    <span
                        className={cn(
                            'text-[10px] font-bold px-2 py-0.5 rounded-full border shrink-0',
                            riskColors[item.risk]
                        )}
                    >
                        {item.label}
                    </span>
                </motion.div>
            ))}
        </motion.div>
    );
}

// ═══════════════════════════════════════════════════════════════════
//  VenturesSection — full-page standalone route
// ═══════════════════════════════════════════════════════════════════
export default function VenturesSection() {
    useEffect(() => {
        document.title = 'Ventures — Enver Cetin';
        const meta = document.querySelector('meta[name="description"]');
        if (meta) {
            meta.setAttribute(
                'content',
                'AI-powered products by Enver Cetin. Featuring VertragsKlar — German contract analysis with an AI Council framework.'
            );
        }
        return () => {
            document.title = 'Enver Cetin — AI Leader & Architect';
        };
    }, []);

    return (
        <section className="relative min-h-screen flex flex-col items-center justify-center bg-slate-950 overflow-hidden selection:bg-blue-500/30 selection:text-blue-200">
            {/* ── Background layers ──────────────────────────── */}
            <div className="absolute inset-0 bg-gradient-to-b from-slate-950 via-[#0c1222] to-slate-950" />

            {/* Grid texture */}
            <div
                className="absolute inset-0 opacity-[0.035] pointer-events-none"
                style={{
                    backgroundImage:
                        'linear-gradient(rgba(255,255,255,0.08) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.08) 1px, transparent 1px)',
                    backgroundSize: '72px 72px',
                }}
            />

            {/* Ambient glow blobs */}
            <div className="absolute top-1/4 -left-40 w-[500px] h-[500px] bg-blue-600/[0.07] rounded-full blur-[120px] pointer-events-none" />
            <div className="absolute bottom-1/4 -right-40 w-[500px] h-[500px] bg-violet-600/[0.06] rounded-full blur-[120px] pointer-events-none" />

            {/* ── Back navigation ─────────────────────────────── */}
            <motion.a
                href="#home"
                initial={{ opacity: 0, x: -12 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.5, delay: 0.1 }}
                className="absolute top-8 left-8 z-30 flex items-center gap-2 text-slate-500 hover:text-slate-300 transition-colors text-sm font-medium tracking-wide"
            >
                <ArrowLeft className="w-4 h-4" />
                Back
            </motion.a>

            {/* ── Content ────────────────────────────────────── */}
            <motion.div
                variants={containerVariants}
                initial="hidden"
                animate="visible"
                className="relative z-20 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24 sm:py-32"
            >
                {/* Section header */}
                <div className="mb-16 sm:mb-20 text-center">
                    <motion.p
                        variants={itemVariants}
                        className="text-sm font-bold text-blue-400 uppercase tracking-[0.2em] mb-4"
                    >
                        Ventures
                    </motion.p>
                    <motion.h2
                        variants={itemVariants}
                        className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4 tracking-tight"
                    >
                        Products I'm Building
                    </motion.h2>
                    <motion.p
                        variants={itemVariants}
                        className="text-base sm:text-lg text-slate-400 max-w-2xl mx-auto leading-relaxed"
                    >
                        Beyond enterprise consulting, I build AI-powered products that
                        solve real problems. Here's what's live.
                    </motion.p>
                </div>

                {/* ── Glassmorphism card ──────────────────────── */}
                <motion.div
                    variants={itemVariants}
                    className="relative max-w-5xl mx-auto rounded-2xl border border-white/[0.08] bg-white/[0.03] backdrop-blur-xl shadow-2xl shadow-black/30"
                >
                    {/* Top edge highlight */}
                    <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/20 to-transparent rounded-t-2xl" />

                    {/* Inner glow accent */}
                    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-2/3 h-32 bg-blue-500/[0.04] blur-3xl pointer-events-none" />

                    <div className="relative grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 p-6 sm:p-8 lg:p-10">
                        {/* ── Left: Product info ─────────────── */}
                        <div className="space-y-6">
                            {/* Status + name */}
                            <div>
                                <div className="flex items-center gap-2 mb-3">
                                    <span className="relative flex h-2 w-2">
                                        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                                        <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
                                    </span>
                                    <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-[0.15em]">
                                        Live
                                    </span>
                                </div>

                                <div className="flex items-center gap-3 mb-2">
                                    <div className="w-9 h-9 rounded-lg bg-blue-500/10 border border-blue-500/20 flex items-center justify-center">
                                        <Scale className="w-4.5 h-4.5 text-blue-400" />
                                    </div>
                                    <h3 className="text-2xl sm:text-3xl font-bold text-white tracking-tight">
                                        VertragsKlar
                                    </h3>
                                </div>

                                <p className="text-slate-400 text-sm sm:text-base font-medium">
                                    AI-Powered German Contract Analysis
                                </p>
                            </div>

                            {/* Description */}
                            <p className="text-slate-400/90 text-sm leading-relaxed">
                                Upload any rental, employment, or service contract and
                                receive a clause-by-clause risk report in under 2 minutes.
                                Powered by an{' '}
                                <span className="text-blue-400 font-medium">
                                    AI Council of 5 legal experts
                                </span>{' '}
                                that cross-validate findings and deliver actionable
                                negotiation recommendations.
                            </p>

                            {/* Feature grid */}
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                                {features.map((f) => (
                                    <div
                                        key={f.title}
                                        className="flex items-start gap-3 p-3 rounded-xl bg-white/[0.03] border border-white/[0.05] hover:bg-white/[0.05] transition-colors duration-300"
                                    >
                                        <div className="w-8 h-8 rounded-lg bg-blue-500/10 border border-blue-500/15 flex items-center justify-center shrink-0 mt-0.5">
                                            <f.icon className="w-4 h-4 text-blue-400" />
                                        </div>
                                        <div className="min-w-0">
                                            <p className="text-white/90 text-xs font-semibold tracking-tight">
                                                {f.title}
                                            </p>
                                            <p className="text-slate-500 text-[11px] leading-snug mt-0.5">
                                                {f.desc}
                                            </p>
                                        </div>
                                    </div>
                                ))}
                            </div>

                            {/* CTAs */}
                            <div className="flex flex-col sm:flex-row gap-3 pt-2">
                                <MagneticButton>
                                    <a
                                        href="https://vertragsklar.de"
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="inline-flex items-center justify-center px-7 py-3 bg-blue-500 text-white font-semibold text-sm rounded-xl hover:bg-blue-400 transition-all duration-200 shadow-lg shadow-blue-500/25 hover:shadow-blue-400/35 hover:-translate-y-0.5 active:translate-y-0"
                                    >
                                        Try VertragsKlar
                                        <ExternalLink className="ml-2 w-3.5 h-3.5" />
                                    </a>
                                </MagneticButton>
                                <MagneticButton>
                                    <a
                                        href="https://vertragsklar.de"
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="inline-flex items-center justify-center px-7 py-3 bg-white/[0.04] text-slate-300 font-medium text-sm rounded-xl border border-white/[0.08] hover:bg-white/[0.08] hover:text-white transition-all duration-200"
                                    >
                                        Learn More
                                        <ArrowRight className="ml-2 w-3.5 h-3.5" />
                                    </a>
                                </MagneticButton>
                            </div>
                        </div>

                        {/* ── Right: Interactive preview ─────── */}
                        <div className="flex items-center">
                            <InteractivePreview />
                        </div>
                    </div>
                </motion.div>

                {/* ── "More coming" teaser ────────────────────── */}
                <motion.div
                    variants={itemVariants}
                    className="mt-14 flex items-center justify-center gap-4"
                >
                    <div className="h-px w-14 bg-gradient-to-r from-transparent to-slate-700" />
                    <p className="text-sm text-slate-600 font-medium tracking-wide">
                        More ventures in the pipeline
                    </p>
                    <div className="h-px w-14 bg-gradient-to-l from-transparent to-slate-700" />
                </motion.div>
            </motion.div>
        </section>
    );
}
