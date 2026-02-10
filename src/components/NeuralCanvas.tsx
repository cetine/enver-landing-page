import { useRef, useEffect, useCallback } from 'react';

/* ───────────── Types ───────────── */

interface SynapseNode {
    x: number;
    y: number;
    vx: number;
    vy: number;
    radius: number;
    activation: number;
    pulsePhase: number;
    connections: number[];
}

interface SynapseEdge {
    from: number;
    to: number;
    opacity: number;
}

interface EnergyParticle {
    edgeIndex: number;
    progress: number;
    speed: number;
    direction: 1 | -1;
    alpha: number;
}

/* ───────────── Constants ───────────── */

const MARGIN = 50;
const CONNECTION_DISTANCE = 150;
const CONNECTION_DISTANCE_MOBILE = 120;
const MOUSE_RADIUS = 140;
const PROPAGATION_THRESHOLD = 0.25;
const PROPAGATION_STRENGTH = 0.18;
const MAX_PARTICLES = 60;
const ACTIVATION_DECAY = 0.982;
const NODE_COUNT = 100;
const NODE_COUNT_MOBILE = 55;
const MIN_NODE_SPACING = 40;

/* ───────────── Utilities ───────────── */

function lerp(a: number, b: number, t: number): number {
    return a + (b - a) * t;
}

function isMobile(): boolean {
    return typeof window !== 'undefined' && window.innerWidth < 640;
}

/* ───────────── Generation ───────────── */

function generateNodes(w: number, h: number): SynapseNode[] {
    const count = isMobile() ? NODE_COUNT_MOBILE : NODE_COUNT;
    const nodes: SynapseNode[] = [];
    let attempts = 0;

    while (nodes.length < count && attempts < count * 25) {
        const x = MARGIN + Math.random() * (w - 2 * MARGIN);
        const y = MARGIN + Math.random() * (h - 2 * MARGIN);

        let tooClose = false;
        for (const n of nodes) {
            const dx = n.x - x;
            const dy = n.y - y;
            if (dx * dx + dy * dy < MIN_NODE_SPACING * MIN_NODE_SPACING) {
                tooClose = true;
                break;
            }
        }

        if (!tooClose) {
            nodes.push({
                x,
                y,
                vx: (Math.random() - 0.5) * 0.3,
                vy: (Math.random() - 0.5) * 0.3,
                radius: 1.5 + Math.random() * 2,
                activation: 0,
                pulsePhase: Math.random() * Math.PI * 2,
                connections: [],
            });
        }
        attempts++;
    }

    return nodes;
}

function generateEdges(nodes: SynapseNode[]): SynapseEdge[] {
    const edges: SynapseEdge[] = [];
    const maxDist = isMobile() ? CONNECTION_DISTANCE_MOBILE : CONNECTION_DISTANCE;

    for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
            const dx = nodes[i].x - nodes[j].x;
            const dy = nodes[i].y - nodes[j].y;
            const dist = Math.sqrt(dx * dx + dy * dy);

            if (dist < maxDist) {
                nodes[i].connections.push(j);
                nodes[j].connections.push(i);
                edges.push({
                    from: i,
                    to: j,
                    opacity: 1.0 - dist / maxDist,
                });
            }
        }
    }

    return edges;
}

/* ───────────── Simulation ───────────── */

function updateNodes(nodes: SynapseNode[], w: number, h: number): void {
    for (const node of nodes) {
        node.x += node.vx;
        node.y += node.vy;

        if (node.x < MARGIN || node.x > w - MARGIN) node.vx *= -1;
        if (node.y < MARGIN || node.y > h - MARGIN) node.vy *= -1;

        node.x = Math.max(MARGIN, Math.min(w - MARGIN, node.x));
        node.y = Math.max(MARGIN, Math.min(h - MARGIN, node.y));
    }
}

function updateActivations(
    nodes: SynapseNode[],
    mouse: { x: number; y: number },
): void {
    for (const node of nodes) {
        const dx = node.x - mouse.x;
        const dy = node.y - mouse.y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < MOUSE_RADIUS) {
            const intensity = 1.0 - dist / MOUSE_RADIUS;
            node.activation = Math.max(node.activation, intensity * intensity);
        }

        node.activation *= ACTIVATION_DECAY;
        if (node.activation < 0.008) node.activation = 0;
    }
}

function propagateActivations(nodes: SynapseNode[]): void {
    const snapshot = nodes.map(n => n.activation);

    for (let i = 0; i < nodes.length; i++) {
        if (snapshot[i] > PROPAGATION_THRESHOLD) {
            for (const j of nodes[i].connections) {
                const transfer = snapshot[i] * PROPAGATION_STRENGTH;
                nodes[j].activation = Math.max(nodes[j].activation, transfer);
            }
        }
    }
}

function triggerAmbientFiring(nodes: SynapseNode[]): void {
    if (Math.random() < 0.008) {
        const idx = Math.floor(Math.random() * nodes.length);
        nodes[idx].activation = Math.max(
            nodes[idx].activation,
            0.3 + Math.random() * 0.2,
        );
    }
}

/* ───────────── Particles ───────────── */

function spawnParticles(
    nodes: SynapseNode[],
    edges: SynapseEdge[],
    particles: EnergyParticle[],
): void {
    if (particles.length >= MAX_PARTICLES) return;

    for (let i = 0; i < edges.length; i++) {
        const edge = edges[i];
        const a = nodes[edge.from];
        const b = nodes[edge.to];
        const diff = a.activation - b.activation;
        const absDiff = Math.abs(diff);

        if (absDiff > 0.15 && Math.max(a.activation, b.activation) > 0.35) {
            if (Math.random() < 0.025) {
                particles.push({
                    edgeIndex: i,
                    progress: 0,
                    speed: 0.012 + Math.random() * 0.018,
                    direction: diff > 0 ? 1 : -1,
                    alpha: 0.6 + Math.random() * 0.4,
                });
                if (particles.length >= MAX_PARTICLES) return;
            }
        }
    }
}

function updateParticles(particles: EnergyParticle[]): void {
    for (const p of particles) {
        p.progress += p.speed;
    }
    for (let i = particles.length - 1; i >= 0; i--) {
        if (particles[i].progress >= 1.0) {
            particles.splice(i, 1);
        }
    }
}

/* ───────────── Drawing ───────────── */

function drawEdges(
    ctx: CanvasRenderingContext2D,
    nodes: SynapseNode[],
    edges: SynapseEdge[],
): void {
    for (const edge of edges) {
        const nodeA = nodes[edge.from];
        const nodeB = nodes[edge.to];

        const activationBoost = Math.max(nodeA.activation, nodeB.activation);
        const alpha = edge.opacity * 0.08 + activationBoost * 0.45;

        if (alpha < 0.01) continue;

        const r = Math.round(lerp(100, 96, activationBoost));
        const g = Math.round(lerp(116, 180, activationBoost));
        const bl = Math.round(lerp(139, 250, activationBoost));

        ctx.beginPath();
        ctx.moveTo(nodeA.x, nodeA.y);
        ctx.lineTo(nodeB.x, nodeB.y);
        ctx.strokeStyle = `rgba(${r}, ${g}, ${bl}, ${alpha})`;
        ctx.lineWidth = 0.4 + activationBoost * 1.2;
        ctx.stroke();
    }
}

function drawNodes(ctx: CanvasRenderingContext2D, nodes: SynapseNode[]): void {
    const time = performance.now() * 0.001;

    for (const node of nodes) {
        const pulse = Math.sin(time * 1.2 + node.pulsePhase) * 0.25 + 1.0;
        const r = node.radius * pulse;

        // Outer glow for activated nodes
        if (node.activation > 0.04) {
            const glowRadius = r + node.activation * 18;
            const gradient = ctx.createRadialGradient(
                node.x,
                node.y,
                r * 0.5,
                node.x,
                node.y,
                glowRadius,
            );
            const coreIntensity = Math.min(node.activation * 1.5, 1);
            gradient.addColorStop(
                0,
                `rgba(180, 220, 255, ${coreIntensity * 0.5})`,
            );
            gradient.addColorStop(
                0.3,
                `rgba(96, 180, 250, ${node.activation * 0.4})`,
            );
            gradient.addColorStop(1, 'rgba(59, 130, 246, 0)');

            ctx.beginPath();
            ctx.arc(node.x, node.y, glowRadius, 0, Math.PI * 2);
            ctx.fillStyle = gradient;
            ctx.fill();
        }

        // Core dot
        const coreAlpha = 0.25 + node.activation * 0.75;
        const cR = Math.round(lerp(148, 160, node.activation));
        const cG = Math.round(lerp(163, 210, node.activation));
        const cB = Math.round(lerp(184, 255, node.activation));

        ctx.beginPath();
        ctx.arc(node.x, node.y, r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(${cR}, ${cG}, ${cB}, ${coreAlpha})`;
        ctx.fill();

        // Bright center pip for highly activated nodes
        if (node.activation > 0.5) {
            const pipAlpha = (node.activation - 0.5) * 2;
            ctx.beginPath();
            ctx.arc(node.x, node.y, r * 0.4, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(220, 240, 255, ${pipAlpha * 0.8})`;
            ctx.fill();
        }
    }
}

function drawParticles(
    ctx: CanvasRenderingContext2D,
    nodes: SynapseNode[],
    edges: SynapseEdge[],
    particles: EnergyParticle[],
): void {
    for (const p of particles) {
        const edge = edges[p.edgeIndex];
        const nodeA = nodes[edge.from];
        const nodeB = nodes[edge.to];

        const t = p.direction === 1 ? p.progress : 1.0 - p.progress;
        const px = nodeA.x + (nodeB.x - nodeA.x) * t;
        const py = nodeA.y + (nodeB.y - nodeA.y) * t;

        const edgeFade = Math.min(p.progress * 5, (1 - p.progress) * 5, 1);
        const alpha = p.alpha * edgeFade;

        const gradient = ctx.createRadialGradient(px, py, 0, px, py, 5);
        gradient.addColorStop(0, `rgba(190, 220, 255, ${alpha * 0.95})`);
        gradient.addColorStop(0.4, `rgba(96, 180, 250, ${alpha * 0.5})`);
        gradient.addColorStop(1, 'rgba(59, 130, 246, 0)');

        ctx.beginPath();
        ctx.arc(px, py, 5, 0, Math.PI * 2);
        ctx.fillStyle = gradient;
        ctx.fill();
    }
}

/* ───────────── Component ───────────── */

export default function NeuralCanvas() {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const animationRef = useRef<number>(0);
    const nodesRef = useRef<SynapseNode[]>([]);
    const edgesRef = useRef<SynapseEdge[]>([]);
    const particlesRef = useRef<EnergyParticle[]>([]);
    const mouseRef = useRef({ x: -9999, y: -9999 });

    const initCanvas = useCallback(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const dpr = window.devicePixelRatio || 1;
        const rect = canvas.getBoundingClientRect();
        canvas.width = rect.width * dpr;
        canvas.height = rect.height * dpr;

        nodesRef.current = generateNodes(rect.width, rect.height);
        edgesRef.current = generateEdges(nodesRef.current);
        particlesRef.current = [];
    }, []);

    useEffect(() => {
        initCanvas();

        const canvas = canvasRef.current;
        if (!canvas) return;

        const handleMouseMove = (e: MouseEvent) => {
            const rect = canvas.getBoundingClientRect();
            mouseRef.current = {
                x: e.clientX - rect.left,
                y: e.clientY - rect.top,
            };
        };

        const handleMouseLeave = () => {
            mouseRef.current = { x: -9999, y: -9999 };
        };

        const handleTouchMove = (e: TouchEvent) => {
            const touch = e.touches[0];
            if (!touch) return;
            const rect = canvas.getBoundingClientRect();
            mouseRef.current = {
                x: touch.clientX - rect.left,
                y: touch.clientY - rect.top,
            };
        };

        const handleTouchEnd = () => {
            mouseRef.current = { x: -9999, y: -9999 };
        };

        canvas.addEventListener('mousemove', handleMouseMove);
        canvas.addEventListener('mouseleave', handleMouseLeave);
        canvas.addEventListener('touchmove', handleTouchMove, { passive: true });
        canvas.addEventListener('touchend', handleTouchEnd);

        let resizeTimer: ReturnType<typeof setTimeout>;
        const handleResize = () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(initCanvas, 200);
        };
        window.addEventListener('resize', handleResize);

        const animate = () => {
            const ctx = canvas.getContext('2d');
            if (!ctx) return;

            const dpr = window.devicePixelRatio || 1;

            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.save();
            ctx.scale(dpr, dpr);

            const viewW = canvas.width / dpr;
            const viewH = canvas.height / dpr;

            updateNodes(nodesRef.current, viewW, viewH);
            updateActivations(nodesRef.current, mouseRef.current);
            propagateActivations(nodesRef.current);
            triggerAmbientFiring(nodesRef.current);
            updateParticles(particlesRef.current);
            spawnParticles(
                nodesRef.current,
                edgesRef.current,
                particlesRef.current,
            );

            drawEdges(ctx, nodesRef.current, edgesRef.current);
            drawParticles(
                ctx,
                nodesRef.current,
                edgesRef.current,
                particlesRef.current,
            );
            drawNodes(ctx, nodesRef.current);

            ctx.restore();

            animationRef.current = requestAnimationFrame(animate);
        };

        animationRef.current = requestAnimationFrame(animate);

        return () => {
            cancelAnimationFrame(animationRef.current);
            canvas.removeEventListener('mousemove', handleMouseMove);
            canvas.removeEventListener('mouseleave', handleMouseLeave);
            canvas.removeEventListener('touchmove', handleTouchMove);
            canvas.removeEventListener('touchend', handleTouchEnd);
            window.removeEventListener('resize', handleResize);
            clearTimeout(resizeTimer);
        };
    }, [initCanvas]);

    return (
        <canvas
            ref={canvasRef}
            className="absolute inset-0 z-0"
            style={{ width: '100%', height: '100%' }}
        />
    );
}
