import { motion } from 'framer-motion';
import type { ReactNode } from 'react';

const ease = [0.22, 1, 0.36, 1] as const;

const variants = {
    initial: { opacity: 0, y: 20, filter: 'blur(4px)' },
    enter: {
        opacity: 1,
        y: 0,
        filter: 'blur(0px)',
        transition: { duration: 0.5, ease },
    },
    exit: {
        opacity: 0,
        y: -10,
        filter: 'blur(4px)',
        transition: { duration: 0.3, ease },
    },
};

export default function PageTransition({
    children,
    onEntered,
}: {
    children: ReactNode;
    onEntered?: () => void;
}) {
    return (
        <motion.div
            variants={variants}
            initial="initial"
            animate="enter"
            exit="exit"
            onAnimationComplete={(definition) => {
                if (definition === 'enter') {
                    onEntered?.();
                }
            }}
        >
            {children}
        </motion.div>
    );
}
