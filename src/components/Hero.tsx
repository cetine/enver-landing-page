
import { ArrowRight, ChevronDown } from 'lucide-react';
import { profile } from '../data/profile';
import { motion, AnimatePresence, useScroll, useTransform } from 'framer-motion';
import { useState, useEffect, useRef } from 'react';
import MagneticButton from './MagneticButton';

const aiTopics = [
    'AI Architecture',
    'AI at Scale',
    'Semantic Kernel',
    'Agentic Systems',
    'RAG',
    'Computer Vision',
    'Generative AI',
    'LLM Ops',
    'AI Strategy',
    'Applied AI'
];

export default function Hero() {
    const [topicIndex, setTopicIndex] = useState(0);
    const sectionRef = useRef<HTMLElement>(null);

    const { scrollYProgress } = useScroll({
        target: sectionRef,
        offset: ['start start', 'end start'],
    });

    // Parallax transforms
    const bgY = useTransform(scrollYProgress, [0, 1], [0, -150]);
    const blob1Y = useTransform(scrollYProgress, [0, 1], [0, -100]);
    const blob2Y = useTransform(scrollYProgress, [0, 1], [0, -180]);
    const textOpacity = useTransform(scrollYProgress, [0.3, 0.7], [1, 0]);
    const textY = useTransform(scrollYProgress, [0.3, 0.7], [0, -60]);
    const chevronOpacity = useTransform(scrollYProgress, [0, 0.08], [1, 0]);

    useEffect(() => {
        const interval = setInterval(() => {
            setTopicIndex((prev) => (prev + 1) % aiTopics.length);
        }, 3000);
        return () => clearInterval(interval);
    }, []);

    return (
        <section ref={sectionRef} id="home" className="relative min-h-screen flex flex-col justify-center pt-20 pb-10 overflow-hidden">
            {/* Background decoration with parallax */}
            <motion.div
                className="absolute top-0 right-0 -z-10 w-1/2 h-full bg-gradient-to-bl from-blue-50 to-transparent opacity-50 blur-3xl"
                style={{ y: bgY }}
            />

            <motion.div style={{ opacity: textOpacity, y: textY }} className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">

                {/* Text Content */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.6 }}
                    className="space-y-8"
                >
                    <div className="space-y-2">
                        <h2 className="text-lg font-medium text-blue-600 tracking-wide uppercase">
                            {profile.primaryTitle}
                        </h2>
                        <h1 className="text-5xl sm:text-6xl font-bold text-slate-900 tracking-tight leading-tight">
                            {profile.name}
                        </h1>
                        <p className="text-xl sm:text-2xl text-slate-600 font-light max-w-lg">
                            {profile.tagline}
                        </p>
                    </div>

                    <div className="flex flex-wrap gap-4">
                        <MagneticButton>
                            <a
                                href="#tech-map"
                                className="inline-flex items-center px-6 py-3 bg-slate-900 text-white font-medium rounded-lg hover:bg-slate-800 transition-colors shadow-lg shadow-slate-900/20"
                            >
                                Explore My GenAI Journey
                                <ArrowRight className="ml-2 w-4 h-4" />
                            </a>
                        </MagneticButton>
                    </div>

                    {/* Statement Quote */}
                    <motion.div
                        className="mt-10 relative max-w-2xl"
                        initial="hidden"
                        animate="visible"
                        variants={{
                            hidden: {},
                            visible: { transition: { staggerChildren: 0.18, delayChildren: 0.5 } }
                        }}
                    >
                        {/* Decorative accent line */}
                        <motion.div
                            className="absolute -left-1 top-0 bottom-0 w-[3px] rounded-full"
                            style={{
                                background: 'linear-gradient(180deg, #7c3aed 0%, #2563eb 50%, #0ea5e9 100%)',
                            }}
                            initial={{ scaleY: 0, originY: 0 }}
                            animate={{ scaleY: 1 }}
                            transition={{ duration: 0.9, delay: 0.4, ease: [0.22, 1, 0.36, 1] }}
                        />

                        <div className="pl-7 space-y-3">
                            {/* Line 1 — the bold hook */}
                            <motion.p
                                className="text-2xl sm:text-3xl font-bold tracking-tight"
                                style={{
                                    background: 'linear-gradient(135deg, #1e293b 0%, #7c3aed 100%)',
                                    WebkitBackgroundClip: 'text',
                                    WebkitTextFillColor: 'transparent',
                                    backgroundClip: 'text',
                                }}
                                variants={{
                                    hidden: { opacity: 0, x: -16, filter: 'blur(6px)' },
                                    visible: { opacity: 1, x: 0, filter: 'blur(0px)', transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } }
                                }}
                            >
                                I build AI that actually works.
                            </motion.p>

                            {/* Lines 2 & 3 — the negations */}
                            <div className="flex gap-4 sm:gap-6">
                                <motion.span
                                    className="text-lg sm:text-xl text-slate-400 font-light italic tracking-wide"
                                    variants={{
                                        hidden: { opacity: 0, y: 10 },
                                        visible: { opacity: 1, y: 0, transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] } }
                                    }}
                                >
                                    Not in labs.
                                </motion.span>
                                <motion.span
                                    className="text-lg sm:text-xl text-slate-400 font-light italic tracking-wide"
                                    variants={{
                                        hidden: { opacity: 0, y: 10 },
                                        visible: { opacity: 1, y: 0, transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] } }
                                    }}
                                >
                                    Not in theory.
                                </motion.span>
                            </div>

                            {/* Line 4 — the punchline */}
                            <motion.p
                                className="text-base sm:text-lg text-slate-600 leading-relaxed font-normal"
                                variants={{
                                    hidden: { opacity: 0, x: -12, filter: 'blur(4px)' },
                                    visible: { opacity: 1, x: 0, filter: 'blur(0px)', transition: { duration: 0.7, ease: [0.22, 1, 0.36, 1] } }
                                }}
                            >
                                But inside the{' '}
                                <span className="font-semibold text-slate-800">German Mittelstand</span>
                                {' '}and{' '}
                                <span className="font-semibold text-slate-800">Fortune 500</span>
                                {' '}companies that run the world's supply chains, finance, and industries.
                            </motion.p>

                            {/* Subtle animated dot accent */}
                            <motion.div
                                className="flex gap-1.5 pt-1"
                                variants={{
                                    hidden: {},
                                    visible: { transition: { staggerChildren: 0.1, delayChildren: 0.3 } }
                                }}
                            >
                                {[
                                    'bg-violet-500',
                                    'bg-blue-500',
                                    'bg-sky-400',
                                ].map((color, i) => (
                                    <motion.div
                                        key={i}
                                        className={`w-1.5 h-1.5 rounded-full ${color}`}
                                        variants={{
                                            hidden: { scale: 0, opacity: 0 },
                                            visible: { scale: 1, opacity: 0.7, transition: { duration: 0.4, ease: 'backOut' } }
                                        }}
                                    />
                                ))}
                            </motion.div>
                        </div>
                    </motion.div>

                </motion.div>

                {/* Visual Abstract */}
                <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ duration: 0.8, delay: 0.2 }}
                    className="relative hidden lg:flex flex-col items-center justify-center h-[500px]"
                >
                    {/* Abstract Geometric Shapes with parallax */}
                    <motion.div
                        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-blue-100 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob"
                        style={{ y: blob1Y }}
                    />
                    <motion.div
                        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-purple-100 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob animation-delay-2000"
                        style={{ y: blob2Y }}
                    />

                    {/* Profile Photo */}
                    <motion.div
                        initial={{ opacity: 0, y: 16 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.7, delay: 0.4 }}
                        className="relative z-10 mb-6"
                    >
                        <div className="w-56 h-56 rounded-2xl overflow-hidden ring-4 ring-white shadow-2xl shadow-slate-900/10">
                            <img
                                src="/images/Enver_Cetin.png"
                                alt={profile.name}
                                className="w-full h-full object-cover object-top"
                            />
                        </div>
                    </motion.div>

                    {/* Rotating AI Topics */}
                    <motion.div
                        initial={{ opacity: 0, y: 12 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.6, delay: 0.6 }}
                        className="relative z-10 px-6 py-3 border border-slate-200 rounded-xl backdrop-blur-sm bg-white/40 shadow-lg overflow-hidden min-w-[220px]"
                    >
                        <AnimatePresence mode="wait">
                            <motion.div
                                key={topicIndex}
                                initial={{ opacity: 0, y: 20, filter: 'blur(4px)' }}
                                animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
                                exit={{ opacity: 0, y: -20, filter: 'blur(4px)' }}
                                transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
                                className="text-slate-500 font-light text-sm tracking-widest uppercase text-center"
                            >
                                {aiTopics[topicIndex]}
                            </motion.div>
                        </AnimatePresence>
                    </motion.div>
                </motion.div>
            </motion.div>

            <motion.div
                className="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce text-slate-400"
                style={{ opacity: chevronOpacity }}
            >
                <ChevronDown size={24} />
            </motion.div>
        </section>
    );
}
