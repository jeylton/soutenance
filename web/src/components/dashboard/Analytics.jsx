import React, { useEffect, useState } from 'react';
import { TrendingUp, GraduationCap, CheckCircle2, Zap, BarChart3, Users, Clock, Target } from 'lucide-react';

const AnalyticStat = ({ label, value, sub, icon: Icon, color }) => (
    <div className="stat-card p-8 flex flex-col justify-between relative overflow-hidden group border-[#1A2E28] hover:border-[#00C88C]/30 transition-all">
        <div className="flex justify-between items-start mb-8 relative z-10">
            <div className="p-4 rounded-[1.25rem] border border-[#1A2E28] transition-all group-hover:scale-110 shadow-2xl bg-[#11241E]" style={{ color }}>
                <Icon size={24} />
            </div>
            {sub && <span className="text-[10px] font-black bg-[#00C88C]/10 text-[#00C88C] px-3 py-1.5 rounded-full tracking-widest leading-none shadow-sm">{sub}</span>}
        </div>
        <div>
            <p className="text-[10px] font-black uppercase text-slate-500 tracking-[0.2em] mb-2">{label}</p>
            <h3 className="text-4xl font-black text-white tracking-tight">{value}</h3>
        </div>
        <div className="absolute -bottom-6 -right-6 opacity-5 group-hover:scale-110 transition-transform duration-700 pointer-events-none" style={{ color }}>
            <Icon size={140} />
        </div>
    </div>
);

const ProgressBar = ({ label, value, percentage, color = "#00C88C" }) => (
    <div className="space-y-3">
        <div className="flex justify-between items-end">
            <span className="text-sm font-bold text-white tracking-tight">{label}</span>
            <span className="text-[10px] font-black uppercase tracking-widest" style={{ color }}>{value}</span>
        </div>
        <div className="h-2.5 bg-[#0D1B17] rounded-full overflow-hidden border border-[#1A2E28]">
            <div
                className="h-full rounded-full transition-all duration-1000 ease-out shadow-[0_0_10px_rgba(0,200,140,0.3)]"
                style={{ width: percentage, backgroundColor: color }}
            ></div>
        </div>
    </div>
);

const StudentProgress = ({ name, code, status, percentage }) => (
    <div className="flex items-center space-x-5 py-3 border-b border-[#1A2E28]/30 last:border-0 group">
        <div className="w-12 h-12 bg-[#11241E] border border-[#1A2E28] rounded-[1.25rem] flex items-center justify-center text-[10px] font-black text-[#00C88C] shadow-lg group-hover:scale-110 transition-transform">
            {code}
        </div>
        <div className="flex-1 space-y-2">
            <div className="flex justify-between items-center">
                <span className="text-sm font-black text-white group-hover:text-[#00C88C] transition-colors tracking-tight">{name}</span>
                <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">{status}</span>
            </div>
            <div className="h-1.5 bg-[#0D1B17] rounded-full overflow-hidden border border-[#1A2E28]/50">
                <div
                    className="h-full bg-[#00C88C] rounded-full transition-all duration-1000 shadow-[0_0_5px_rgba(0,200,140,0.5)]"
                    style={{ width: percentage }}
                ></div>
            </div>
        </div>
    </div>
);

const Analytics = () => {
    const api = import.meta.env.VITE_API_URL;
    const [metrics, setMetrics] = useState(null);
    const [sessions, setSessions] = useState([]);

    useEffect(() => {
        fetch(`${api}/api/metrics`)
            .then(r => r.json())
            .then(d => setMetrics(d))
            .catch(() => {});
        fetch(`${api}/api/sessions`)
            .then(r => r.json())
            .then(d => setSessions(d.sessions || []))
            .catch(() => {});
    }, []);

    // Compute stats from sessions
    const completedSessions = sessions.filter(s => s.score != null);
    const avgScore = completedSessions.length > 0
        ? (completedSessions.reduce((sum, s) => sum + (s.score || 0), 0) / completedSessions.length).toFixed(1)
        : '—';
    const passRate = completedSessions.length > 0
        ? ((completedSessions.filter(s => s.score >= 10).length / completedSessions.length) * 100).toFixed(1) + '%'
        : '—';

    // Time analytics
    const sessionsWithTime = sessions.filter(s => s.time_spent > 0);
    const avgTime = sessionsWithTime.length > 0
        ? Math.round(sessionsWithTime.reduce((sum, s) => sum + s.time_spent, 0) / sessionsWithTime.length)
        : 0;
    const formatTime = (secs) => {
        if (!secs) return '—';
        const m = Math.floor(secs / 60);
        const s2 = secs % 60;
        return `${m}m${s2 > 0 ? ` ${s2}s` : ''}`;
    };

    // Exam sessions vs practice
    const examSessions = sessions.filter(s => s.is_exam);
    const practiceSessions = sessions.filter(s => !s.is_exam);

    // Build student list from sessions (group by user)
    const studentMap = {};
    sessions.forEach(s => {
        if (!s.user_id) return;
        if (!studentMap[s.user_id]) {
            studentMap[s.user_id] = { name: s.users?.full_name || s.users?.email || `Étudiant ${s.user_id.slice(0, 4)}`, sessions: 0, completed: 0, totalScore: 0 };
        }
        studentMap[s.user_id].sessions++;
        if (s.score != null) {
            studentMap[s.user_id].completed++;
            studentMap[s.user_id].totalScore += s.score;
        }
    });
    const students = Object.values(studentMap)
        .map(st => ({ ...st, avg: st.completed > 0 ? (st.totalScore / st.completed).toFixed(1) : 0, pct: st.completed > 0 ? Math.round((st.totalScore / st.completed) * 5) : 0 }))
        .sort((a, b) => b.avg - a.avg)
        .slice(0, 5);

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-10">
            {/* Top Stat Row */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
                <AnalyticStat label="Score Moyen" value={avgScore === '—' ? '—' : `${avgScore}/20`} sub={completedSessions.length > 0 ? `${completedSessions.length} éval.` : null} icon={GraduationCap} color="#00C88C" />
                <AnalyticStat label="Taux de Réussite" value={passRate} sub={passRate !== '—' ? '≥10/20' : null} icon={CheckCircle2} color="#00C88C" />
                <AnalyticStat label="Temps Moyen" value={formatTime(avgTime)} sub={sessionsWithTime.length > 0 ? `${sessionsWithTime.length} sessions` : null} icon={Clock} color="#3B82F6" />
                <AnalyticStat label="Sessions Totales" value={metrics?.total_sessions ?? '—'} sub={examSessions.length > 0 ? `${examSessions.length} examens` : null} icon={Zap} color="#A855F7" />
            </div>

            {/* Tendency placeholder */}
            <div className="stat-card p-10 relative overflow-hidden bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                <div className="flex items-center justify-between mb-12">
                    <div className="flex items-center space-x-4">
                        <div className="p-3 bg-[#11241E]/50 rounded-xl text-[#00C88C] border border-[#1A2E28]">
                            <TrendingUp size={20} />
                        </div>
                        <div>
                            <h4 className="text-xl font-black text-white tracking-tight">Tendances de Précision Diagnostic</h4>
                            <p className="text-[10px] text-slate-500 font-bold uppercase tracking-widest">Évolution basée sur les sessions réelles</p>
                        </div>
                    </div>
                </div>
                {completedSessions.length === 0 ? (
                    <div className="h-48 flex items-center justify-center text-slate-600 text-sm font-bold">
                        Aucune session terminée — les tendances apparaîtront ici
                    </div>
                ) : (
                    <div className="h-48 flex items-end gap-2 px-4">
                        {completedSessions.slice(-20).map((s, i) => (
                            <div key={i} className="flex-1 flex flex-col items-center gap-1">
                                <div className="w-full rounded-t-lg bg-[#00C88C]" style={{ height: `${(s.score / 20) * 100}%`, minHeight: 4, opacity: 0.5 + (s.score / 20) * 0.5 }}></div>
                                <span className="text-[7px] text-slate-600 font-bold">{s.score}</span>
                            </div>
                        ))}
                    </div>
                )}
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
                {/* Specialties from metrics */}
                <div className="stat-card p-10 space-y-10">
                    <div className="flex items-center space-x-4">
                        <div className="p-3 bg-[#11241E]/50 rounded-xl text-[#00C88C] border border-[#1A2E28]">
                            <BarChart3 size={20} />
                        </div>
                        <h4 className="text-xl font-black text-white tracking-tight">Spécialités disponibles</h4>
                    </div>
                    {(metrics?.specialty_list || []).length === 0 ? (
                        <div className="text-sm text-slate-600 font-bold">Aucune spécialité enregistrée</div>
                    ) : (
                        <div className="space-y-8">
                            {(metrics?.specialty_list || []).map((sp, i) => (
                                <ProgressBar key={i} label={sp.name} value="—" percentage="0%" />
                            ))}
                        </div>
                    )}
                </div>

                {/* Student Progress - from real sessions */}
                <div className="stat-card p-10 space-y-10">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-4">
                            <div className="p-3 bg-[#11241E]/50 rounded-xl text-[#00C88C] border border-[#1A2E28]">
                                <Users size={20} />
                            </div>
                            <h4 className="text-xl font-black text-white tracking-tight">Progression des Étudiants</h4>
                        </div>
                    </div>
                    {students.length === 0 ? (
                        <div className="text-sm text-slate-600 font-bold">Aucune donnée — les sessions des étudiants apparaîtront ici</div>
                    ) : (
                        <div className="space-y-2">
                            {students.map((st, i) => (
                                <StudentProgress
                                    key={i}
                                    name={st.name}
                                    code={st.name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2)}
                                    status={`${st.avg}/20 moy.`}
                                    percentage={`${st.pct}%`}
                                />
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default Analytics;
