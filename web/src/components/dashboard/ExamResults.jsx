import React, { useState, useEffect, useContext } from 'react';
import { ArrowLeft, Trophy, Clock, User, BookOpen, Download, Search, Filter } from 'lucide-react';
import { AuthContext } from '../../App';

const ExamResults = ({ assignmentId, onBack }) => {
    const { authHeaders } = useContext(AuthContext);
    const api = import.meta.env.VITE_API_URL;
    const [sessions, setSessions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchQuery, setSearchQuery] = useState('');
    const [sortBy, setSortBy] = useState('score-desc');

    useEffect(() => {
        loadResults();
    }, []);

    const loadResults = async () => {
        try {
            const res = await fetch(`${api}/api/sessions?is_exam=true`, { headers: authHeaders });
            const data = await res.json();
            let examSessions = data.sessions || [];
            // Filter by assignment if provided
            if (assignmentId) {
                examSessions = examSessions.filter(s => s.exam_assignment_id === assignmentId);
            }
            setSessions(examSessions);
        } catch (e) {
            console.error('Error loading exam results:', e);
        } finally {
            setLoading(false);
        }
    };

    const filteredSessions = sessions
        .filter(s => {
            if (!searchQuery) return true;
            const q = searchQuery.toLowerCase();
            const studentName = s.users?.full_name || s.users?.email || '';
            const caseName = s.cases?.consultation_reason || s.cases?.patient_name || '';
            return studentName.toLowerCase().includes(q) || caseName.toLowerCase().includes(q);
        })
        .sort((a, b) => {
            switch (sortBy) {
                case 'score-desc': return (b.score || 0) - (a.score || 0);
                case 'score-asc': return (a.score || 0) - (b.score || 0);
                case 'date-desc': return new Date(b.created_at) - new Date(a.created_at);
                case 'date-asc': return new Date(a.created_at) - new Date(b.created_at);
                case 'name': return (a.users?.full_name || '').localeCompare(b.users?.full_name || '');
                default: return 0;
            }
        });

    const avgScore = sessions.length > 0
        ? (sessions.reduce((sum, s) => sum + (s.score || 0), 0) / sessions.length).toFixed(1)
        : 0;
    const maxScore = sessions.length > 0 ? Math.max(...sessions.map(s => s.score || 0)) : 0;
    const minScore = sessions.length > 0 ? Math.min(...sessions.map(s => s.score || 0)) : 0;
    const passRate = sessions.length > 0
        ? ((sessions.filter(s => (s.score || 0) >= 10).length / sessions.length) * 100).toFixed(0)
        : 0;

    const getScoreColor = (score) => {
        if (score >= 16) return 'text-emerald-400';
        if (score >= 12) return 'text-blue-400';
        if (score >= 10) return 'text-yellow-400';
        return 'text-rose-400';
    };

    const getScoreBg = (score) => {
        if (score >= 16) return 'bg-emerald-500/10 border-emerald-500/30';
        if (score >= 12) return 'bg-blue-500/10 border-blue-500/30';
        if (score >= 10) return 'bg-yellow-500/10 border-yellow-500/30';
        return 'bg-rose-500/10 border-rose-500/30';
    };

    const exportCSV = () => {
        const header = 'Étudiant,Email,Cas,Score,Temps (min),Date\n';
        const rows = filteredSessions.map(s => {
            const name = s.users?.full_name || 'N/A';
            const email = s.users?.email || 'N/A';
            const caseName = s.cases?.consultation_reason || s.cases?.patient_name || 'N/A';
            const score = s.score || 0;
            const time = s.time_spent ? Math.round(s.time_spent / 60) : 0;
            const date = new Date(s.created_at).toLocaleDateString('fr-FR');
            return `"${name}","${email}","${caseName}",${score},${time},"${date}"`;
        }).join('\n');
        const blob = new Blob([header + rows], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `resultats_examens_${new Date().toISOString().slice(0, 10)}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    };

    if (loading) return <div className="flex items-center justify-center h-64"><div className="animate-spin w-8 h-8 border-2 border-[#00C88C] border-t-transparent rounded-full"></div></div>;

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-8">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div className="flex items-center space-x-4">
                    {onBack && (
                        <button onClick={onBack} className="p-2 text-slate-400 hover:text-white transition-all">
                            <ArrowLeft size={20} />
                        </button>
                    )}
                    <div>
                        <h3 className="text-2xl font-black text-white">Résultats d'Examens</h3>
                        <p className="text-xs text-slate-500 mt-1 font-bold">{sessions.length} session(s) d'examen</p>
                    </div>
                </div>
                <button onClick={exportCSV} className="btn-primary py-3 px-6 group">
                    <Download size={16} className="mr-2" />
                    <span className="font-black tracking-widest uppercase text-[10px]">Exporter CSV</span>
                </button>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="stat-card p-5 text-center">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mb-2">Moyenne</p>
                    <p className="text-3xl font-black text-white">{avgScore}<span className="text-sm text-slate-500">/20</span></p>
                </div>
                <div className="stat-card p-5 text-center">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mb-2">Meilleur</p>
                    <p className="text-3xl font-black text-emerald-400">{maxScore}<span className="text-sm text-slate-500">/20</span></p>
                </div>
                <div className="stat-card p-5 text-center">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mb-2">Plus bas</p>
                    <p className="text-3xl font-black text-rose-400">{minScore}<span className="text-sm text-slate-500">/20</span></p>
                </div>
                <div className="stat-card p-5 text-center">
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mb-2">Taux réussite</p>
                    <p className="text-3xl font-black text-[#00C88C]">{passRate}<span className="text-sm text-slate-500">%</span></p>
                </div>
            </div>

            {/* Search & Sort */}
            <div className="flex items-center space-x-4">
                <div className="flex-1 relative">
                    <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" />
                    <input
                        type="text"
                        placeholder="Rechercher un étudiant ou cas..."
                        value={searchQuery}
                        onChange={e => setSearchQuery(e.target.value)}
                        className="w-full bg-[#0D1B17] border border-[#1A2E28] rounded-xl py-3 pl-11 pr-4 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold"
                    />
                </div>
                <div className="flex items-center space-x-2">
                    <Filter size={14} className="text-slate-500" />
                    <select value={sortBy} onChange={e => setSortBy(e.target.value)} className="bg-[#0D1B17] border border-[#1A2E28] rounded-xl py-3 px-4 text-sm text-white font-bold focus:outline-none">
                        <option value="score-desc">Score ↓</option>
                        <option value="score-asc">Score ↑</option>
                        <option value="date-desc">Date ↓</option>
                        <option value="date-asc">Date ↑</option>
                        <option value="name">Nom</option>
                    </select>
                </div>
            </div>

            {/* Results Table */}
            <div className="stat-card overflow-hidden">
                <table className="w-full">
                    <thead>
                        <tr className="border-b border-[#1A2E28]">
                            <th className="text-left py-4 px-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">#</th>
                            <th className="text-left py-4 px-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Étudiant</th>
                            <th className="text-left py-4 px-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Cas Clinique</th>
                            <th className="text-center py-4 px-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Score</th>
                            <th className="text-center py-4 px-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Temps</th>
                            <th className="text-left py-4 px-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Date</th>
                            <th className="text-left py-4 px-6 text-[10px] font-black text-slate-500 uppercase tracking-widest">Diagnostic</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredSessions.map((s, i) => (
                            <tr key={s.id} className="border-b border-[#1A2E28]/50 hover:bg-[#0D1B17]/50 transition-all">
                                <td className="py-4 px-6">
                                    <div className="flex items-center space-x-2">
                                        {i === 0 && sortBy === 'score-desc' && <Trophy size={14} className="text-yellow-400" />}
                                        <span className="text-sm font-bold text-slate-400">{i + 1}</span>
                                    </div>
                                </td>
                                <td className="py-4 px-6">
                                    <div className="flex items-center space-x-3">
                                        <div className="w-8 h-8 rounded-lg bg-[#00C88C]/10 flex items-center justify-center">
                                            <User size={14} className="text-[#00C88C]" />
                                        </div>
                                        <div>
                                            <p className="text-sm font-bold text-white">{s.users?.full_name || 'N/A'}</p>
                                            <p className="text-[10px] text-slate-500">{s.users?.email || ''}</p>
                                        </div>
                                    </div>
                                </td>
                                <td className="py-4 px-6">
                                    <div className="flex items-center space-x-2">
                                        <BookOpen size={14} className="text-purple-400" />
                                        <span className="text-sm font-bold text-slate-300">{s.cases?.consultation_reason || s.cases?.patient_name || `Cas #${s.case_id}`}</span>
                                    </div>
                                </td>
                                <td className="py-4 px-6 text-center">
                                    <span className={`inline-flex items-center px-3 py-1.5 rounded-lg border text-sm font-black ${getScoreBg(s.score || 0)} ${getScoreColor(s.score || 0)}`}>
                                        {s.score ?? '—'}/20
                                    </span>
                                </td>
                                <td className="py-4 px-6 text-center">
                                    <div className="flex items-center justify-center space-x-1 text-slate-400">
                                        <Clock size={12} />
                                        <span className="text-sm font-bold">{s.time_spent ? `${Math.round(s.time_spent / 60)}m` : '—'}</span>
                                    </div>
                                </td>
                                <td className="py-4 px-6">
                                    <span className="text-sm font-bold text-slate-400">{new Date(s.created_at).toLocaleDateString('fr-FR')}</span>
                                </td>
                                <td className="py-4 px-6">
                                    <span className="text-xs font-bold text-slate-500 truncate block max-w-[200px]">{s.progress?.conclusion?.diagnosis || '—'}</span>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
                {filteredSessions.length === 0 && (
                    <div className="text-center py-12 text-slate-600">
                        <Trophy size={40} className="mx-auto mb-3 opacity-30" />
                        <p className="text-sm font-bold">Aucun résultat d'examen</p>
                    </div>
                )}
            </div>
        </div>
    );
};

export default ExamResults;
