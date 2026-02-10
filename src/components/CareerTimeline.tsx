import { motion } from 'framer-motion';
import { Briefcase, Calendar, MapPin, Award, Heart, GraduationCap } from 'lucide-react';
import { careerHighlights, volunteerRoles, certifications } from '../data/profile';

export default function CareerTimeline() {
    return (
        <section id="career" className="py-24 bg-white relative overflow-hidden">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

                {/* Header */}
                <div className="text-center mb-16">
                    <h2 className="text-4xl font-bold text-slate-900 mb-4">Career Journey</h2>
                    <p className="text-lg text-slate-600 max-w-2xl mx-auto">
                        Navigating the intersection of AI, automation, and enterprise strategy.
                    </p>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">

                    {/* Main Timeline (Experience) */}
                    <div className="lg:col-span-2 space-y-12">
                        <h3 className="text-2xl font-bold text-slate-800 flex items-center gap-3 mb-8">
                            <Briefcase className="w-6 h-6 text-blue-600" />
                            Professional Experience
                        </h3>

                        <div className="relative border-l-2 border-slate-200 ml-3 space-y-12">
                            {careerHighlights.map((job, index) => (
                                <motion.div
                                    key={index}
                                    initial={{ opacity: 0, x: -20 }}
                                    whileInView={{ opacity: 1, x: 0 }}
                                    viewport={{ once: true }}
                                    transition={{ duration: 0.5, delay: index * 0.1 }}
                                    className="relative pl-8"
                                >
                                    {/* Timeline Dot */}
                                    <div className="absolute -left-[9px] top-0 w-4 h-4 rounded-full bg-blue-600 ring-4 ring-white" />

                                    <div className="space-y-2">
                                        <div className="flex flex-wrap items-baseline justify-between gap-x-4">
                                            <h4 className="text-xl font-bold text-slate-900">{job.role}</h4>
                                            <span className="flex items-center text-sm font-medium text-slate-500 bg-slate-50 px-3 py-1 rounded-full">
                                                <Calendar className="w-3 h-3 mr-2" />
                                                {job.period}
                                            </span>
                                        </div>

                                        <div className="text-lg font-semibold text-blue-700">{job.company}</div>

                                        <div className="flex items-center text-sm text-slate-500 mb-4">
                                            <MapPin className="w-4 h-4 mr-1" />
                                            {job.location}
                                        </div>

                                        <p className="text-slate-600 italic mb-4">{job.summary}</p>

                                        <ul className="space-y-2">
                                            {job.bullets.map((bullet, i) => (
                                                <li key={i} className="flex items-start text-sm text-slate-600">
                                                    <span className="mr-2 mt-1.5 w-1.5 h-1.5 bg-blue-400 rounded-full flex-shrink-0" />
                                                    {bullet}
                                                </li>
                                            ))}
                                        </ul>
                                    </div>
                                </motion.div>
                            ))}
                        </div>
                    </div>

                    {/* Sidebar (Volunteering & Certifications) */}
                    <div className="space-y-16">

                        {/* Volunteering */}
                        <div>
                            <h3 className="text-xl font-bold text-slate-800 flex items-center gap-3 mb-6">
                                <Heart className="w-5 h-5 text-red-500" />
                                Leadership & Volunteering
                            </h3>
                            <div className="space-y-6">
                                {volunteerRoles.map((role, index) => (
                                    <motion.div
                                        key={index}
                                        initial={{ opacity: 0, y: 10 }}
                                        whileInView={{ opacity: 1, y: 0 }}
                                        viewport={{ once: true }}
                                        transition={{ duration: 0.4, delay: index * 0.1 }}
                                        className="bg-slate-50 p-4 rounded-xl border border-slate-100"
                                    >
                                        <div className="font-semibold text-slate-900">{role.role}</div>
                                        <div className="text-sm text-blue-600 font-medium">{role.organization}</div>
                                        <div className="text-xs text-slate-500 mt-1">{role.period}</div>
                                    </motion.div>
                                ))}
                            </div>
                        </div>

                        {/* Certifications */}
                        <div>
                            <h3 className="text-xl font-bold text-slate-800 flex items-center gap-3 mb-6">
                                <Award className="w-5 h-5 text-amber-500" />
                                Certifications
                            </h3>
                            <div className="grid gap-4">
                                {certifications.map((cert, index) => (
                                    <motion.div
                                        key={index}
                                        initial={{ opacity: 0, y: 10 }}
                                        whileInView={{ opacity: 1, y: 0 }}
                                        viewport={{ once: true }}
                                        transition={{ duration: 0.4, delay: 0.2 + (index * 0.1) }}
                                        className="flex items-start gap-3 p-3 rounded-lg hover:bg-slate-50 transition-colors"
                                    >
                                        <GraduationCap className="w-5 h-5 text-slate-400 mt-0.5" />
                                        <div>
                                            <div className="font-medium text-slate-900 text-sm">{cert.name}</div>
                                            <div className="text-xs text-slate-500">
                                                {cert.issuer} • {cert.date}
                                            </div>
                                        </div>
                                    </motion.div>
                                ))}
                            </div>
                        </div>

                    </div>
                </div>
            </div>
        </section>
    );
}
