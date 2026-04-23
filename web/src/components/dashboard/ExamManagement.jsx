import React, { useState, useEffect, useContext } from 'react';
import { Plus, Trash2, Clock, Calendar, Users, BookOpen, ClipboardCheck, Trophy } from 'lucide-react';
import { AuthContext } from '../../App';

const ExamManagement = ({ onViewResults }) => {
    const { authHeaders } = useContext(AuthContext);
    const api = import.meta.env.VITE_API_URL;
    const [assignments, setAssignments] = useState([]);
    const [cases, setCases] = useState([]);
    const [showForm, setShowForm] = useState(false);
    const [form, setForm] = useState({ case_id: '', time_limit: 30, due_date: '' });
    const [saving, setSaving] = useState(false);

    const load = () => {
        fetch(`${api}/api/exam-assignments`, { headers: authHeaders })
            .then(r => r.json())
            .then(d => setAssignments(d.assignments || []))
            .catch(() => []);
        fetch(`${api}/api/cases`)
            .then(r => r.json())
            .then(d => setCases((d.cases || []).filter(c => c.status === 'active')))
            .catch(() => []);
    };

    useEffect(() => { load(); }, []);

    const createAssignment = async () => {
        if (!form.case_id) { alert('Sélectionnez un cas'); return; }
        setSaving(true);
        try {
            const res = await fetch(`${api}/api/exam-assignments`, {
                method: 'POST',
                headers: authHeaders,
                body: JSON.stringify({
                    case_id: Number(form.case_id),
                    time_limit: form.time_limit ? Number(form.time_limit) : null,
                    due_date: form.due_date || null,
                    group_name: null,
                }),
            });
            if (!res.ok) throw new Error('Erreur création');
            setShowForm(false);
            setForm({ case_id: '', time_limit: 30, due_date: '' });
            load();
        } catch (e) {
            alert(e.message);
        } finally {
            setSaving(false);
        }
    };

    const deleteAssignment = async (id) => {
        if (!confirm('Supprimer cet examen ?')) return;
        await fetch(`${api}/api/exam-assignments/${id}`, { method: 'DELETE', headers: authHeaders });
        load();
    };

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-8">
            <div className="flex items-center justify-between">
                <div>
                    <h3 className="text-2xl font-black text-white">Examens Assignés</h3>
                    <p className="text-xs text-slate-500 mt-1 font-bold">{assignments.length} examen(s) programmé(s)</p>
                </div>
                <div className="flex items-center space-x-3">
                <button onClick={() => setShowForm(!showForm)} className="btn-primary py-4 px-8 group">
                    <Plus size={20} className="mr-2" />
                    <span className="font-black tracking-widest uppercase text-[10px]">Nouvel Examen</span>
                </button>
                {onViewResults && (
                    <button onClick={onViewResults} className="py-4 px-8 rounded-2xl border border-purple-500/30 bg-purple-500/10 text-purple-400 hover:bg-purple-500/20 transition-all flex items-center group">
                        <Trophy size={18} className="mr-2" />
                        <span className="font-black tracking-widest uppercase text-[10px]">Résultats</span>
                    </button>
                )}
                </div>
            </div>

            {showForm && (
                <div className="stat-card p-8 bg-gradient-to-br from-[#0D1B17] to-[#050C0A] space-y-6">
                    <h4 className="text-lg font-black text-white flex items-center space-x-3">
                        <ClipboardCheck size={20} className="text-[#00C88C]" />
                        <span>Assigner un examen</span>
                    </h4>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                        <div className="space-y-2">
                            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Cas clinique *</label>
                            <select value={form.case_id} onChange={e => setForm({...form, case_id: e.target.value})} className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-4 px-5 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold">
                                <option value="">— Sélectionner —</option>
                                {cases.map(c => (
                                    <option key={c.id} value={c.id}>{c.consultation_reason || c.patient_name} (ID: {c.id})</option>
                                ))}
                            </select>
                        </div>
                        <div className="space-y-2">
                            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Temps limite (min)</label>
                            <input type="number" value={form.time_limit} onChange={e => setForm({...form, time_limit: e.target.value})} placeholder="30" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-4 px-5 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold" />
                        </div>
                        <div className="space-y-2">
                            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest">Date limite</label>
                            <input type="datetime-local" value={form.due_date} onChange={e => setForm({...form, due_date: e.target.value})} className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-4 px-5 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold" />
                        </div>
                    </div>
                    <div className="flex space-x-4 pt-4">
                        <button onClick={() => setShowForm(false)} className="px-6 py-3 rounded-xl border border-[#1A2E28] text-slate-400 font-bold text-xs uppercase tracking-widest hover:text-white transition-all">Annuler</button>
                        <button disabled={saving} onClick={createAssignment} className="btn-primary py-3 px-8 disabled:opacity-40">
                            <span className="font-black tracking-widest uppercase text-[10px]">{saving ? 'Création...' : 'Assigner'}</span>
                        </button>
                    </div>
                </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {assignments.map((a) => (
                    <div key={a.id} className="stat-card p-6 hover:border-[#00C88C]/40 transition-all">
                        <div className="flex justify-between items-start mb-4">
                            <div className="flex items-center space-x-3">
                                <div className="w-10 h-10 rounded-xl bg-purple-500/10 flex items-center justify-center">
                                    <BookOpen size={18} className="text-purple-400" />
                                </div>
                                <div>
                                    <h4 className="text-sm font-bold text-white">{a.cases?.consultation_reason || a.cases?.patient_name || `Cas #${a.case_id}`}</h4>
                                    <span className="text-[9px] font-black text-purple-400 uppercase tracking-widest">EXAMEN</span>
                                </div>
                            </div>
                            <button onClick={() => deleteAssignment(a.id)} className="p-2 text-slate-600 hover:text-rose-500 transition-all">
                                <Trash2 size={16} />
                            </button>
                        </div>
                        <div className="flex items-center space-x-6 text-xs text-slate-500">
                            {a.time_limit && (
                                <div className="flex items-center space-x-1">
                                    <Clock size={12} />
                                    <span className="font-bold">{a.time_limit} min</span>
                                </div>
                            )}
                            {a.due_date && (
                                <div className="flex items-center space-x-1">
                                    <Calendar size={12} />
                                    <span className="font-bold">{new Date(a.due_date).toLocaleDateString()}</span>
                                </div>
                            )}
                            {a.group_name && (
                                <div className="flex items-center space-x-1">
                                    <Users size={12} />
                                    <span className="font-bold">{a.group_name}</span>
                                </div>
                            )}
                        </div>
                    </div>
                ))}
                {assignments.length === 0 && (
                    <div className="col-span-2 text-center py-16 text-slate-600">
                        <ClipboardCheck size={48} className="mx-auto mb-4 opacity-30" />
                        <p className="text-sm font-bold">Aucun examen assigné</p>
                        <p className="text-xs text-slate-700 mt-1">Cliquez sur "Nouvel Examen" pour assigner un cas en mode examen</p>
                    </div>
                )}
            </div>
        </div>
    );
};

export default ExamManagement;
