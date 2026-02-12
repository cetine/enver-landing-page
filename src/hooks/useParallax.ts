import { useRef } from 'react';
import { useScroll, useTransform, type MotionValue } from 'framer-motion';

/**
 * Returns a MotionValue that maps the element's scroll progress to a parallax offset.
 * @param range - [start, end] pixel offsets. E.g. [0, -150] moves element up 150px over scroll.
 */
export function useParallax(range: [number, number]): {
    ref: React.RefObject<HTMLElement | null>;
    value: MotionValue<number>;
} {
    const ref = useRef<HTMLElement>(null);
    const { scrollYProgress } = useScroll({
        target: ref,
        offset: ['start end', 'end start'],
    });
    const value = useTransform(scrollYProgress, [0, 1], range);

    return { ref, value };
}
