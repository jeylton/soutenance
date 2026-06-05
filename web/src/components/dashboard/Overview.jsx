import React, { useEffect, useState } from 'react';
import { TrendingUp, Users, BookOpen, FileText, Star, Activity, Clock, AlertTriangle, Zap, CheckCircle2 } from 'lucide-react';

const StatCard = ({ label, value, icon: Icon }) => (
    <div className="stat-card relative overflow-hidden group">
        <div className="flex justify-between items-start mb-4">
            <div className="p-3 bg-[#11241E] rounded-xl text-[#00C88C] border border-[#1A2E28]">
                <Icon size={20} />
            </div>
        </div>
        <p className="text-slate-400 text-[10px] font-bold uppercase tracking-widest mb-1">{label}</p>
        <h3 className="text-4xl font-bold text-white tracking-tight">{value}</h3>
        <div className="absolute -bottom-2 -right-2 opacity-10 group-hover:scale-110 transition-transform duration-500 text-[#00C88C]">
            <Icon size={100} />
        </div>
    </div>
);

const CaseItem = ({ title, difficulty, status, updatedAt }) => (
    <div className="flex items-center justify-between p-4 bg-[#081310] border border-[#1A2E28] rounded-xl hover:border-[#00C88C]/30 transition-all cursor-pointer group">
        <div className="flex items-center space-x-4">
            <div className="w-12 h-12 bg-[#11241E] rounded-xl flex items-center justify-center text-[#00C88C] border border-[#1A2E28] group-hover:scale-110 transition-transform">
                <BookOpen size={20} />
            </div>
            <div>
                <h5 className="text-sm font-bold text-white group-hover:text-[#00C88C] transition-colors">{title}</h5>
                <div className="flex items-center space-x-2 mt-1">
                    <div className="flex space-x-0.5">
                        {[...Array(5)].map((_, i) => (
                            <Star key={i} size={10} className={i < difficulty ? "fill-[#00C88C] text-[#00C88C]" : "text-slate-800"} />
                        ))}
                    </div>
                </div>
            </div>
        </div>
        <div className="text-right">
            <span className="text-[10px] font-bold uppercase tracking-widest block mb-1 text-[#00C88C]">{status === 'active' ? 'ACTIF' : status}</span>
            {updatedAt && (
                <div className="flex items-center space-x-1 text-slate-600">
                    <Clock size={10} />
                    <p className="text-[9px]">{new Date(updatedAt).toLocaleDateString('fr-FR')}</p>
                </div>
            )}
        </div>
    </div>
);

const Overview = () => {
    const api = import.meta.env.VITE_API_URL;
    const [metrics, setMetrics] = useState({
        mobile_users: 0,
        clinics: 0,
        published_courses: 0,
        specialties: 0,
        active_recent_cases: 0,
        total_sessions: 0,
        recent_cases: [],
        specialty_list: [],
    });
    const [sessions, setSessions] = useState([]);
    const [lastUpdated, setLastUpdated] = useState(null);

    const loadAll = () => {
        fetch(`${api}/api/metrics`)
            .then((res) => res.json())
            .then((data) => { setMetrics((prev) => ({ ...prev, ...data })); setLastUpdated(new Date()); })
            .catch(() => {});
        fetch(`${api}/api/sessions`)
            .then(r => r.json())
            .then(d => setSessions(d.sessions || []))
            .catch(() => {});
    };

    useEffect(() => {
        loadAll();
        const interval = setInterval(loadAll, 30000); // Refresh toutes les 30s
        return () => clearInterval(interval);
    }, []);

    // Stats calculées depuis les sessions
    const today = new Date().toDateString();
    const sessionsToday = sessions.filter(s => new Date(s.created_at).toDateString() === today).length;
    const completedSessions = sessions.filter(s => s.score != null);
    const avgScore = completedSessions.length > 0
        ? (completedSessions.reduce((sum, s) => sum + (s.score || 0), 0) / completedSessions.length).toFixed(1)
        : null;
    const passRate = completedSessions.length > 0
        ? Math.round((completedSessions.filter(s => s.score >= 10).length / completedSessions.length) * 100)
        : null;

    // Top 3 cas les plus échoués (score moyen le plus bas)
    const casesScoreMap = {};
    completedSessions.forEach(s => {
        if (!s.case_id) return;
        if (!casesScoreMap[s.case_id]) casesScoreMap[s.case_id] = { total: 0, count: 0, name: s.cases?.consultation_reason || `Cas #${s.case_id}` };
        casesScoreMap[s.case_id].total += s.score;
        casesScoreMap[s.case_id].count += 1;
    });
    const hardestCases = Object.entries(casesScoreMap)
        .map(([id, d]) => ({ id, avg: (d.total / d.count).toFixed(1), count: d.count, name: d.name }))
        .filter(c => c.count >= 2)
        .sort((a, b) => a.avg - b.avg)
        .slice(0, 3);

    const totalSpecialties = metrics.specialty_list?.length || metrics.specialties || 0;

    return (
        <div className="animate-in fade-in duration-500 space-y-10">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard label="Total Utilisateurs (mobile)" value={String(metrics.mobile_users)} icon={Users} />
                <StatCard label="Cas Cliniques Actifs" value={String(metrics.active_recent_cases)} icon={BookOpen} />
                <StatCard label="Sessions" value={String(metrics.total_sessions)} icon={Activity} />
            </div>

            {/* Bilan Rapide Temps Réel */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {/* Sessions aujourd'hui */}
                <div className="stat-card p-6 border-[#1A2E28] hover:border-[#00C88C]/30 transition-all">
                    <div className="flex items-center space-x-3 mb-3">
                        <div className="w-8 h-8 rounded-xl bg-[#00C88C]/10 flex items-center justify-center"><Zap size={16} className="text-[#00C88C]" /></div>
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Aujourd'hui</span>
                        <div className="w-2 h-2 rounded-full bg-[#00C88C] animate-pulse ml-auto" />
                    </div>
                    <p className="text-3xl font-black text-white">{sessionsToday}</p>
                    <p className="text-[10px] text-slate-600 font-bold mt-1">sessions lancées</p>
                </div>

                {/* Score moyen */}
                <div className="stat-card p-6 border-[#1A2E28] hover:border-[#3b82f6]/30 transition-all">
                    <div className="flex items-center space-x-3 mb-3">
                        <div className="w-8 h-8 rounded-xl bg-blue-500/10 flex items-center justify-center"><TrendingUp size={16} className="text-blue-400" /></div>
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Score Moyen</span>
                    </div>
                    <p className="text-3xl font-black text-white">{avgScore ? `${avgScore}/20` : '—'}</p>
                    <p className="text-[10px] text-slate-600 font-bold mt-1">{completedSessions.length} évaluations</p>
                </div>

                {/* Taux réussite */}
                <div className="stat-card p-6 border-[#1A2E28] hover:border-[#22c55e]/30 transition-all">
                    <div className="flex items-center space-x-3 mb-3">
                        <div className="w-8 h-8 rounded-xl bg-green-500/10 flex items-center justify-center"><CheckCircle2 size={16} className="text-green-400" /></div>
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Taux Réussite</span>
                    </div>
                    <p className="text-3xl font-black text-white">{passRate !== null ? `${passRate}%` : '—'}</p>
                    <p className="text-[10px] text-slate-600 font-bold mt-1">score ≥ 10/20</p>
                </div>

                {/* Cas les plus difficiles */}
                <div className="stat-card p-6 border-[#1A2E28] hover:border-rose-500/30 transition-all">
                    <div className="flex items-center space-x-3 mb-3">
                        <div className="w-8 h-8 rounded-xl bg-rose-500/10 flex items-center justify-center"><AlertTriangle size={16} className="text-rose-400" /></div>
                        <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Cas Difficiles</span>
                    </div>
                    {hardestCases.length === 0 ? (
                        <p className="text-sm text-slate-600 font-bold mt-2">Pas encore de données</p>
                    ) : (
                        <div className="space-y-2 mt-1">
                            {hardestCases.map((c, i) => (
                                <div key={c.id} className="flex items-center justify-between">
                                    <span className="text-[10px] text-slate-400 truncate max-w-[120px]">{c.name}</span>
                                    <span className="text-[10px] font-black text-rose-400">{c.avg}/20</span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* Indicateur dernière mise à jour */}
            {lastUpdated && (
                <div className="flex items-center justify-end space-x-2 text-[9px] text-slate-700">
                    <div className="w-1.5 h-1.5 rounded-full bg-[#00C88C] animate-pulse" />
                    <span>Mis à jour à {lastUpdated.toLocaleTimeString('fr-FR')} • Actualisation auto toutes les 30s</span>
                </div>
            )}

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <div className="lg:col-span-1 stat-card">
                    <h4 className="text-sm font-bold text-white mb-8 flex items-center space-x-2">
                        <TrendingUp size={16} className="text-[#00C88C]" />
                        <span>Spécialités</span>
                    </h4>
                    <div className="relative h-64 flex items-center justify-center mb-8">
                        <div className="w-48 h-48 rounded-full border-[12px] border-[#0D1B17] border-t-[#00C88C] border-r-[#00C88C]/60 flex flex-col items-center justify-center">
                            <span className="text-3xl font-bold text-white">{totalSpecialties}</span>
                            <span className="text-[10px] text-slate-500 uppercase font-bold tracking-widest">Domaines</span>
                        </div>
                    </div>
                    <div className="space-y-3">
                        {metrics.specialty_list && metrics.specialty_list.length > 0 ? (
                            metrics.specialty_list.map((spec, idx) => {
                                const colors = ['#00C88C', '#00C88C99', '#00C88C66', '#00C88C44', '#00C88C33'];
                                return (
                                    <div key={spec.id} className="flex items-center justify-between text-xs">
                                        <div className="flex items-center space-x-2">
                                            <div className="w-2 h-2 rounded-full" style={{ background: colors[idx % colors.length] }}></div>
                                            <span className="text-slate-400">{spec.name}</span>
                                        </div>
                                    </div>
                                );
                            })
                        ) : (
                            <div className="text-xs text-slate-600">Aucune spécialité enregistrée</div>
                        )}
                    </div>
                </div>

                <div className="lg:col-span-2 space-y-8">
                    <div className="stat-card">
                        <div className="flex items-center justify-between mb-8">
                            <h4 className="text-sm font-bold text-white flex items-center space-x-2">
                                <BookOpen size={16} className="text-[#00C88C]" />
                                <span>Cas Cliniques Récents</span>
                            </h4>
                            <span className="text-[10px] font-bold text-slate-600 uppercase tracking-widest">
                                {metrics.active_recent_cases} actif{metrics.active_recent_cases > 1 ? 's' : ''}
                            </span>
                        </div>
                        <div className="space-y-4">
                            {(!metrics.recent_cases || metrics.recent_cases.length === 0) ? (
                                <div className="text-center py-12">
                                    <BookOpen size={40} className="text-slate-800 mx-auto mb-4" />
                                    <p className="text-sm text-slate-500">Aucun cas clinique actif</p>
                                    <p className="text-[10px] text-slate-700 mt-1">Créez un cas clinique depuis la section &quot;Cas Cliniques&quot;</p>
                                </div>
                            ) : (
                                metrics.recent_cases.map((c) => (
                                    <CaseItem
                                        key={c.id}
                                        title={c.consultation_reason || c.patient_name}
                                        difficulty={c.difficulty || 1}
                                        status={c.status}
                                        updatedAt={c.updated_at}
                                    />
                                ))
                            )}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Overview;
