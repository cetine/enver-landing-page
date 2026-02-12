import { motion } from 'framer-motion';
import { useMagneticEffect } from '../hooks/useMagneticEffect';
import type { ReactNode } from 'react';

export default function MagneticButton({
    children,
    strength = 0.3,
    radius = 80,
    className = '',
}: {
    children: ReactNode;
    strength?: number;
    radius?: number;
    className?: string;
}) {
    const { ref, x, y, onMouseMove, onMouseLeave } = useMagneticEffect(strength, radius);

    return (
        <motion.div
            ref={ref}
            style={{ x, y }}
            onMouseMove={onMouseMove}
            onMouseLeave={onMouseLeave}
            className={`inline-block ${className}`}
        >
            {children}
        </motion.div>
    );
}
