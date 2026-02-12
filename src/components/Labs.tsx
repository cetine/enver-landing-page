
import { motion } from 'framer-motion';
import { ArrowLeft, FlaskConical } from 'lucide-react';
import { useEffect } from 'react';
import NeuralCanvas from './NeuralCanvas';

export default function Labs() {
    useEffect(() => {
        document.title = 'Labs — Enver Cetin';
        const meta = document.querySelector('meta[name="description"]');
        if (meta) {
            meta.setAttribute('content', 'Labs — Coming soon. Experiments in AI, automation, and applied intelligence by Enver Cetin.');
        }
        return () => {
            document.title = 'Enver Cetin — AI Leader & Architect';
        };
    }, []);

    return (
        <section className="relative min-h-screen flex flex-col items-center justify-center bg-slate-950 overflow-hidden selection:bg-blue-500/30 selection:text-blue-200">

            {/* Interactive neural synapse network */}
            <NeuralCanvas />

            {/* Subtle grid texture */}
            <div
                className="absolute inset-0 opacity-[0.03] pointer-events-none"
                style={{
                    backgroundImage: `linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)`,
                    backgroundSize: '64px 64px',
                }}
            />

            {/* Faint radial glow */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-blue-500/5 rounded-full blur-3xl pointer-events-none" />

            {/* Back navigation */}
            <motion.a
                href="#home"
                initial={{ opacity: 0, x: -12 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.5, delay: 0.1 }}
                className="absolute top-8 left-8 z-10 flex items-center gap-2 text-slate-500 hover:text-slate-300 transition-colors text-sm font-medium tracking-wide"
            >
                <ArrowLeft className="w-4 h-4" />
                Back
            </motion.a>

            {/* Main content */}
            <div className="relative z-10 flex flex-col items-center text-center px-6 max-w-lg">

                {/* Animated icon */}
                <motion.div
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
                    className="mb-10"
                >
                    <div className="relative w-16 h-16 flex items-center justify-center">
                        {/* Pulsing ring */}
                        <motion.div
                            className="absolute inset-0 rounded-full border border-blue-500/20"
                            animate={{ scale: [1, 1.5, 1.5], opacity: [0.4, 0, 0] }}
                            transition={{ duration: 3, repeat: Infinity, ease: 'easeOut' }}
                        />
                        <motion.div
                            className="absolute inset-0 rounded-full border border-blue-500/20"
                            animate={{ scale: [1, 1.5, 1.5], opacity: [0.4, 0, 0] }}
                            transition={{ duration: 3, repeat: Infinity, ease: 'easeOut', delay: 1 }}
                        />
                        <div className="w-12 h-12 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center">
                            <FlaskConical className="w-5 h-5 text-blue-400" />
                        </div>
                    </div>
                </motion.div>

                {/* Title */}
                <motion.h1
                    initial={{ opacity: 0, y: 16 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.6, delay: 0.15 }}
                    className="text-3xl sm:text-4xl font-bold text-slate-100 tracking-tight mb-4"
                >
                    Labs
                </motion.h1>

                {/* Description */}
                <motion.p
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, delay: 0.3 }}
                    className="text-slate-500 text-base leading-relaxed mb-8"
                >
                    A space for experiments in AI, automation, and applied intelligence. Currently setting up the workbench.
                </motion.p>

                {/* Status indicator */}
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: 0.5, delay: 0.45 }}
                    className="flex items-center gap-2.5 px-4 py-2 rounded-full border border-slate-800 bg-slate-900/60"
                >
                    <span className="relative flex h-2 w-2">
                        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75" />
                        <span className="relative inline-flex rounded-full h-2 w-2 bg-blue-500" />
                    </span>
                    <span className="text-xs font-medium text-slate-400 tracking-widest uppercase">
                        Coming Soon
                    </span>
                </motion.div>
            </div>
        </section>
    );
}
