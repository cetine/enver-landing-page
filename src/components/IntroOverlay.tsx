import { motion } from 'framer-motion';

const ease = [0.22, 1, 0.36, 1] as const;

const nameChars = 'Enver Cetin'.split('');

export default function IntroOverlay({ onComplete }: { onComplete: () => void }) {
    return (
        <motion.div
            key="intro-overlay"
            className="fixed inset-0 z-[9999] flex flex-col items-center justify-center bg-slate-950"
            initial={{ clipPath: 'inset(0 0 0 0)' }}
            exit={{ clipPath: 'inset(0 0 100% 0)' }}
            transition={{ duration: 0.6, ease, delay: 0.1 }}
            onAnimationComplete={(definition) => {
                if (definition === 'exit') return;
            }}
        >
            {/* Ambient glow */}
            <motion.div
                className="absolute w-[400px] h-[400px] rounded-full bg-violet-500/10 blur-[100px]"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.4 }}
            />

            {/* Name reveal */}
            <motion.div
                className="relative flex overflow-hidden"
                initial="hidden"
                animate="visible"
                variants={{
                    hidden: {},
                    visible: {
                        transition: { staggerChildren: 0.04, delayChildren: 0.4 },
                    },
                }}
            >
                {nameChars.map((char, i) => (
                    <motion.span
                        key={i}
                        className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight"
                        style={{
                            background: 'linear-gradient(135deg, #e2e8f0 0%, #7c3aed 100%)',
                            WebkitBackgroundClip: 'text',
                            WebkitTextFillColor: 'transparent',
                            backgroundClip: 'text',
                        }}
                        variants={{
                            hidden: { opacity: 0, y: 40, filter: 'blur(8px)' },
                            visible: {
                                opacity: 1,
                                y: 0,
                                filter: 'blur(0px)',
                                transition: { duration: 0.5, ease },
                            },
                        }}
                    >
                        {char === ' ' ? '\u00A0' : char}
                    </motion.span>
                ))}
            </motion.div>

            {/* Subtitle */}
            <motion.p
                className="mt-4 text-slate-500 text-sm sm:text-base tracking-widest uppercase"
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, ease, delay: 1.2 }}
            >
                AI Leader & Architect
            </motion.p>

            {/* Signature dots */}
            <motion.div
                className="flex gap-1.5 mt-6"
                initial="hidden"
                animate="visible"
                variants={{
                    hidden: {},
                    visible: { transition: { staggerChildren: 0.1, delayChildren: 1.5 } },
                }}
            >
                {['bg-violet-500', 'bg-blue-500', 'bg-sky-400'].map((color, i) => (
                    <motion.div
                        key={i}
                        className={`w-1.5 h-1.5 rounded-full ${color}`}
                        variants={{
                            hidden: { scale: 0, opacity: 0 },
                            visible: {
                                scale: 1,
                                opacity: 0.7,
                                transition: { duration: 0.4, ease: 'backOut' },
                            },
                        }}
                    />
                ))}
            </motion.div>

            {/* Auto-complete after animation finishes */}
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 0 }}
                transition={{ delay: 2.2 }}
                onAnimationComplete={() => onComplete()}
            />
        </motion.div>
    );
}
