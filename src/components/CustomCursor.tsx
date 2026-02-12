import { useEffect, useRef, useState } from 'react';

export default function CustomCursor() {
    const outerRef = useRef<HTMLDivElement>(null);
    const innerRef = useRef<HTMLDivElement>(null);
    const pos = useRef({ x: -100, y: -100 });
    const [hovering, setHovering] = useState(false);
    const [visible, setVisible] = useState(false);
    const isTouchDevice = useRef(false);

    useEffect(() => {
        // Don't show on touch devices
        if (
            'ontouchstart' in window ||
            window.matchMedia('(pointer: coarse)').matches
        ) {
            isTouchDevice.current = true;
            return;
        }

        document.documentElement.classList.add('custom-cursor-active');

        const onMove = (e: PointerEvent) => {
            pos.current = { x: e.clientX, y: e.clientY };
            if (!visible) setVisible(true);

            // Update inner dot immediately via ref
            if (innerRef.current) {
                innerRef.current.style.transform = `translate3d(${e.clientX - 3}px, ${e.clientY - 3}px, 0)`;
            }
            // Outer ring follows with CSS transition
            if (outerRef.current) {
                outerRef.current.style.transform = `translate3d(${e.clientX - 12}px, ${e.clientY - 12}px, 0) scale(${hovering ? 1.5 : 1})`;
            }
        };

        const onOver = (e: MouseEvent) => {
            const target = e.target as Element;
            if (target.closest('a, button, [data-cursor="pointer"], input, textarea, select')) {
                setHovering(true);
            }
        };

        const onOut = (e: MouseEvent) => {
            const target = e.target as Element;
            if (target.closest('a, button, [data-cursor="pointer"], input, textarea, select')) {
                setHovering(false);
            }
        };

        const onLeave = () => setVisible(false);
        const onEnter = () => setVisible(true);

        document.addEventListener('pointermove', onMove);
        document.addEventListener('mouseover', onOver);
        document.addEventListener('mouseout', onOut);
        document.documentElement.addEventListener('mouseleave', onLeave);
        document.documentElement.addEventListener('mouseenter', onEnter);

        return () => {
            document.documentElement.classList.remove('custom-cursor-active');
            document.removeEventListener('pointermove', onMove);
            document.removeEventListener('mouseover', onOver);
            document.removeEventListener('mouseout', onOut);
            document.documentElement.removeEventListener('mouseleave', onLeave);
            document.documentElement.removeEventListener('mouseenter', onEnter);
        };
    }, [visible, hovering]);

    // Update outer ring scale when hover state changes
    useEffect(() => {
        if (isTouchDevice.current) return;
        if (outerRef.current) {
            const { x, y } = pos.current;
            outerRef.current.style.transform = `translate3d(${x - 12}px, ${y - 12}px, 0) scale(${hovering ? 1.5 : 1})`;
        }
    }, [hovering]);

    if (isTouchDevice.current) return null;

    return (
        <>
            {/* Outer ring */}
            <div
                ref={outerRef}
                className="fixed top-0 left-0 pointer-events-none z-[9998] will-change-transform"
                style={{
                    width: 24,
                    height: 24,
                    borderRadius: '50%',
                    border: '1px solid rgba(124, 58, 237, 0.5)',
                    transition: 'transform 0.15s ease-out, opacity 0.2s',
                    opacity: visible ? 1 : 0,
                }}
            />
            {/* Inner dot */}
            <div
                ref={innerRef}
                className="fixed top-0 left-0 pointer-events-none z-[9998] will-change-transform"
                style={{
                    width: 6,
                    height: 6,
                    borderRadius: '50%',
                    backgroundColor: 'rgba(124, 58, 237, 0.8)',
                    transition: 'opacity 0.2s',
                    opacity: visible ? 1 : 0,
                }}
            />
        </>
    );
}
