import { useScroll, useTransform, motion } from 'framer-motion';

export default function ParallaxBackground() {
    const { scrollYProgress } = useScroll();

    // Layer 1: slow, large shapes
    const y1 = useTransform(scrollYProgress, [0, 1], [0, -80]);
    // Layer 2: medium speed
    const y2 = useTransform(scrollYProgress, [0, 1], [0, -200]);
    // Layer 3: faster, smaller accents
    const y3 = useTransform(scrollYProgress, [0, 1], [0, -350]);

    return (
        <div className="absolute inset-0 overflow-hidden pointer-events-none -z-10" aria-hidden>
            {/* Layer 1 — large faint circles */}
            <motion.div style={{ y: y1 }} className="absolute inset-0">
                <div className="absolute top-[30%] -left-20 w-[500px] h-[500px] rounded-full bg-blue-100/30 blur-3xl" />
                <div className="absolute top-[70%] -right-20 w-[400px] h-[400px] rounded-full bg-violet-100/20 blur-3xl" />
            </motion.div>

            {/* Layer 2 — medium gradient blobs */}
            <motion.div style={{ y: y2 }} className="absolute inset-0">
                <div className="absolute top-[50%] left-[20%] w-[250px] h-[250px] rounded-full bg-sky-100/25 blur-2xl" />
                <div className="absolute top-[20%] right-[15%] w-[200px] h-[200px] rounded-full bg-purple-100/20 blur-2xl" />
            </motion.div>

            {/* Layer 3 — small accent dots */}
            <motion.div style={{ y: y3 }} className="absolute inset-0">
                <div className="absolute top-[40%] left-[40%] w-3 h-3 rounded-full bg-violet-400/20" />
                <div className="absolute top-[60%] right-[30%] w-2 h-2 rounded-full bg-blue-400/25" />
                <div className="absolute top-[80%] left-[60%] w-2.5 h-2.5 rounded-full bg-sky-400/20" />
            </motion.div>
        </div>
    );
}
