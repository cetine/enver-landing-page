import { useMotionValue, useSpring, type MotionValue } from 'framer-motion';
import { useCallback, useRef } from 'react';

interface MagneticEffect {
    ref: React.RefObject<HTMLDivElement | null>;
    x: MotionValue<number>;
    y: MotionValue<number>;
    onMouseMove: (e: React.MouseEvent) => void;
    onMouseLeave: () => void;
}

export function useMagneticEffect(
    strength: number = 0.3,
    radius: number = 80,
): MagneticEffect {
    const ref = useRef<HTMLDivElement>(null);
    const x = useMotionValue(0);
    const y = useMotionValue(0);
    const springX = useSpring(x, { stiffness: 150, damping: 15 });
    const springY = useSpring(y, { stiffness: 150, damping: 15 });

    const onMouseMove = useCallback(
        (e: React.MouseEvent) => {
            if (!ref.current) return;
            const rect = ref.current.getBoundingClientRect();
            const cx = rect.left + rect.width / 2;
            const cy = rect.top + rect.height / 2;
            const dx = e.clientX - cx;
            const dy = e.clientY - cy;
            const dist = Math.sqrt(dx * dx + dy * dy);

            if (dist < radius) {
                x.set(dx * strength);
                y.set(dy * strength);
            } else {
                x.set(0);
                y.set(0);
            }
        },
        [strength, radius, x, y],
    );

    const onMouseLeave = useCallback(() => {
        x.set(0);
        y.set(0);
    }, [x, y]);

    return { ref, x: springX, y: springY, onMouseMove, onMouseLeave };
}
