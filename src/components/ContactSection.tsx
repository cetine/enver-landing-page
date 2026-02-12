
import { useState } from 'react';
import { motion } from 'framer-motion';
import { Mail, Linkedin, Send, CheckCircle, AlertCircle, Loader2 } from 'lucide-react';
import MagneticButton from './MagneticButton';

const CONTACT_EMAIL = 'Envercetin.work@gmail.com';
const WEB3FORMS_KEY = import.meta.env.VITE_WEB3FORMS_KEY || '';

type FormStatus = 'idle' | 'sending' | 'success' | 'error';

export default function ContactSection() {
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [message, setMessage] = useState('');
    const [status, setStatus] = useState<FormStatus>('idle');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setStatus('sending');

        try {
            const res = await fetch('https://api.web3forms.com/submit', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    access_key: WEB3FORMS_KEY,
                    name,
                    email,
                    message,
                    from_name: 'Enver Landing Page',
                    subject: `New message from ${name}`,
                }),
            });

            const data = await res.json();

            if (data.success) {
                setStatus('success');
                setName('');
                setEmail('');
                setMessage('');
                setTimeout(() => setStatus('idle'), 5000);
            } else {
                setStatus('error');
                setTimeout(() => setStatus('idle'), 5000);
            }
        } catch {
            setStatus('error');
            setTimeout(() => setStatus('idle'), 5000);
        }
    };

    return (
        <section id="contact" className="py-20 bg-white border-t border-slate-100">
            <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
                <motion.div
                    initial={{ opacity: 0, y: 30 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true, margin: '-80px' }}
                    transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
                >
                    <h2 className="text-3xl font-bold text-slate-900 mb-6">Get in touch</h2>
                    <p className="text-lg text-slate-600 mb-10">
                        Open to speaking about AI strategy, agentic systems and applied automation.
                    </p>
                </motion.div>

                <motion.div
                    className="flex flex-col sm:flex-row justify-center gap-4 mb-12"
                    initial={{ opacity: 0, y: 20 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true, margin: '-60px' }}
                    transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1], delay: 0.1 }}
                >
                    <MagneticButton>
                        <a
                            href={`mailto:${CONTACT_EMAIL}`}
                            className="inline-flex items-center justify-center px-6 py-3 bg-slate-900 text-white font-medium rounded-lg hover:bg-slate-800 transition-colors"
                        >
                            <Mail className="mr-2 w-4 h-4" />
                            Email Me
                        </a>
                    </MagneticButton>
                    <MagneticButton>
                        <a
                            href="https://linkedin.com/in/enver-cetin"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center justify-center px-6 py-3 bg-white text-slate-700 border border-slate-200 font-medium rounded-lg hover:bg-slate-50 transition-colors"
                        >
                            <Linkedin className="mr-2 w-4 h-4" />
                            LinkedIn
                        </a>
                    </MagneticButton>
                </motion.div>

                {/* Web3Forms-powered contact form */}
                <motion.div
                    className="bg-slate-50 p-8 rounded-2xl border border-slate-100 text-left"
                    initial={{ opacity: 0, y: 40, rotateX: 2 }}
                    whileInView={{ opacity: 1, y: 0, rotateX: 0 }}
                    viewport={{ once: true, margin: '-60px' }}
                    transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1], delay: 0.15 }}
                    style={{ perspective: 800 }}
                >
                    <h3 className="text-sm font-semibold text-slate-900 uppercase tracking-wider mb-6">Send a quick message</h3>
                    <form className="space-y-4" onSubmit={handleSubmit}>
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <div>
                                <label htmlFor="name" className="block text-sm font-medium text-slate-700 mb-1">Name</label>
                                <input
                                    type="text"
                                    id="name"
                                    required
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    className="w-full px-4 py-2 rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                                    placeholder="Your name"
                                    disabled={status === 'sending'}
                                />
                            </div>
                            <div>
                                <label htmlFor="email" className="block text-sm font-medium text-slate-700 mb-1">Email</label>
                                <input
                                    type="email"
                                    id="email"
                                    required
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    className="w-full px-4 py-2 rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                                    placeholder="john@example.com"
                                    disabled={status === 'sending'}
                                />
                            </div>
                        </div>
                        <div>
                            <label htmlFor="message" className="block text-sm font-medium text-slate-700 mb-1">Message</label>
                            <textarea
                                id="message"
                                rows={4}
                                required
                                value={message}
                                onChange={(e) => setMessage(e.target.value)}
                                className="w-full px-4 py-2 rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all"
                                placeholder="How can we collaborate?"
                                disabled={status === 'sending'}
                            ></textarea>
                        </div>

                        {/* Status feedback */}
                        {status === 'success' && (
                            <div className="flex items-center gap-2 text-green-700 bg-green-50 border border-green-200 px-4 py-3 rounded-lg text-sm">
                                <CheckCircle className="w-4 h-4 flex-shrink-0" />
                                Message sent! I'll get back to you soon.
                            </div>
                        )}
                        {status === 'error' && (
                            <div className="flex items-center gap-2 text-red-700 bg-red-50 border border-red-200 px-4 py-3 rounded-lg text-sm">
                                <AlertCircle className="w-4 h-4 flex-shrink-0" />
                                Something went wrong. Please try again or email me directly.
                            </div>
                        )}

                        <button
                            type="submit"
                            disabled={status === 'sending'}
                            className={`w-full sm:w-auto px-6 py-2.5 font-medium rounded-lg transition-colors flex items-center justify-center ${status === 'sending'
                                    ? 'bg-blue-400 text-white cursor-not-allowed'
                                    : 'bg-blue-600 text-white hover:bg-blue-700'
                                }`}
                        >
                            {status === 'sending' ? (
                                <>
                                    Sending…
                                    <Loader2 className="ml-2 w-4 h-4 animate-spin" />
                                </>
                            ) : (
                                <>
                                    Send Message
                                    <Send className="ml-2 w-4 h-4" />
                                </>
                            )}
                        </button>
                    </form>
                </motion.div>

                <footer className="mt-20 text-sm text-slate-400">
                    © {new Date().getFullYear()} Enver Cetin. Built with React & Tailwind.
                </footer>
            </div>
        </section>
    );
}
