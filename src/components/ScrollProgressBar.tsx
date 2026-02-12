import { motion, useScroll } from 'framer-motion';

export default function ScrollProgressBar() {
    const { scrollYProgress } = useScroll();

    return (
        <motion.div
            className="fixed top-0 left-0 right-0 h-[3px] z-[60] origin-left"
            style={{
                scaleX: scrollYProgress,
                background: 'linear-gradient(90deg, #7c3aed, #2563eb, #0ea5e9)',
            }}
        />
    );
}
