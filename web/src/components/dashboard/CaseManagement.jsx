import React, { useEffect, useState } from 'react';
import { Search, Plus, Edit2, Eye, LayoutGrid, List, Star, Clock, Archive, RotateCcw, Trash2 } from 'lucide-react';

const statusLabel = (s) => s === 'active' ? 'ACTIF' : s === 'draft' ? 'BROUILLON' : 'ARCHIVÉ';
const CaseCard = ({ status, id, title, specialty, difficulty, modifiedAt, idx, onArchive, onRestore, onEdit, onView }) => {
    const isActif = status === 'active';
    const isBrouillon = status === 'draft';
    const isArchive = status === 'archived';

    return (
        <div className="stat-card p-8 group relative overflow-hidden flex flex-col h-full hover:border-[#00C88C]/40 transition-all duration-300">
            <div className="flex justify-between items-start mb-10">
                <div className="flex space-x-3">
                    <span className={`text-[9px] font-black px-3 py-1.5 rounded-lg tracking-widest ${isActif ? 'bg-[#00C88C]/10 text-[#00C88C]' :
                        isBrouillon ? 'bg-amber-500/10 text-amber-500' :
                            'bg-slate-500/10 text-slate-500'
                        }`}>
                        {status}
                    </span>
                    <span className="text-[9px] text-slate-600 font-bold px-3 py-1.5 bg-[#050C0A] rounded-lg border border-[#1A2E28]">ID: {id}</span>
                </div>
                <div className="flex space-x-1.5 shadow-2xl">
                    {isArchive ? (
                        <>
                            <button onClick={onRestore} className="p-2.5 bg-[#11241E] text-slate-400 hover:text-[#00C88C] rounded-xl border border-[#1A2E28] transition-all">
                                <RotateCcw size={16} />
                            </button>
                            <button onClick={onView} className="p-2.5 bg-[#11241E] text-slate-400 hover:text-white rounded-xl border border-[#1A2E28] transition-all">
                                <Eye size={16} />
                            </button>
                            <button className="p-2.5 bg-[#11241E] text-slate-400 hover:text-rose-500 rounded-xl border border-[#1A2E28] transition-all">
                                <Trash2 size={16} />
                            </button>
                        </>
                    ) : (
                        <>
                            <button onClick={onEdit} className="p-2.5 bg-[#11241E] text-slate-400 hover:text-[#00C88C] rounded-xl border border-[#1A2E28] transition-all">
                                <Edit2 size={16} />
                            </button>
                            <button onClick={onView} className="p-2.5 bg-[#11241E] text-slate-400 hover:text-white rounded-xl border border-[#1A2E28] transition-all">
                                <Eye size={16} />
                            </button>
                            <button onClick={onArchive} className="p-2.5 bg-[#11241E] text-slate-400 hover:text-amber-500 rounded-xl border border-[#1A2E28] transition-all">
                                <Archive size={16} />
                            </button>
                        </>
                    )}
                </div>
            </div>

            <h3 className="text-2xl font-bold text-white mb-2 leading-tight group-hover:text-[#00C88C] transition-colors line-clamp-2">
                {title}
            </h3>
            <p className="text-[10px] text-[#00C88C] font-black uppercase tracking-[0.2em] mb-12">{specialty || 'SANS SPÉCIALITÉ'}</p>

            <div className="mt-auto space-y-6">
                <div>
                    <p className="text-[9px] text-slate-600 uppercase font-black tracking-widest mb-3">Difficulté</p>
                    <div className="flex space-x-1">
                        {[...Array(5)].map((_, i) => (
                            <Star
                                key={i}
                                size={14}
                                className={i < difficulty ? "fill-[#00C88C] text-[#00C88C]" : "text-slate-800"}
                            />
                        ))}
                    </div>
                </div>

                <div className="flex items-center justify-between pt-6 border-t border-[#1A2E28]">
                    <div className="flex items-center space-x-2 text-slate-600">
                        <Clock size={12} />
                        <span className="text-[9px] font-bold uppercase tracking-widest">Modifié {modifiedAt}</span>
                    </div>
                    {isActif && <div className="w-1.5 h-1.5 rounded-full bg-[#00C88C] shadow-[0_0_8px_#00C88C]"></div>}
                </div>
            </div>
        </div>
    );
};

const CaseManagement = ({ onCreateNew, onViewCase, onEditCase }) => {
    const api = import.meta.env.VITE_API_URL;
    const [cases, setCases] = useState([]);
    const [specialties, setSpecialties] = useState([]);
    const [filter, setFilter] = useState('all');
    const [searchQuery, setSearchQuery] = useState('');

    const loadCases = () => {
        fetch(`${api}/api/cases`)
            .then((res) => res.json())
            .then((data) => setCases(data.cases || []))
            .catch(() => setCases([]));
    };
    useEffect(() => {
        loadCases();
        fetch(`${api}/api/specialties`)
            .then(r => r.json())
            .then(d => setSpecialties(d.specialties || []))
            .catch(() => {});
    }, []);

    const patchStatus = async (id, status) => {
        await fetch(`${api}/api/cases/${id}/status`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status }),
        });
        loadCases();
    };

    const handleEdit = async (caseId) => {
        try {
            const res = await fetch(`${api}/api/cases/${caseId}`);
            const data = await res.json();
            if (data.case && onEditCase) {
                onEditCase(data.case);
            }
        } catch (e) {
            console.error('Failed to load case for edit:', e);
        }
    };

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-8">
            {/* Filters and Actions */}
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
                <div className="flex flex-1 max-w-2xl">
                    <div className="relative w-full group">
                        <Search className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-600 group-focus-within:text-[#00C88C] transition-colors" size={20} />
                        <input
                            type="text"
                            placeholder="Rechercher un cas clinique..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="w-full bg-[#0D1B17] border border-[#1A2E28] rounded-[1.5rem] py-5 pl-16 pr-8 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold placeholder:text-slate-700 shadow-inner"
                        />
                    </div>
                </div>

                <div className="flex items-center space-x-3 bg-[#081310] p-1.5 rounded-2xl border border-[#1A2E28]">
                    {['Tous', 'Actifs', 'Brouillons', 'Archivés'].map((tab, idx) => (
                        <button
                            key={tab}
                            onClick={() => setFilter(['all','active','draft','archived'][idx])}
                            className={`px-6 py-2.5 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${filter === ['all','active','draft','archived'][idx]
                                ? 'bg-[#00C88C] text-[#050C0A] shadow-[0_0_15px_rgba(0,200,140,0.3)]'
                                : 'text-slate-500 hover:text-[#00C88C] hover:bg-[#11241E]'
                                }`}
                        >
                            {tab}
                        </button>
                    ))}
                </div>
            </div>

            <button
                onClick={onCreateNew}
                className="btn-primary py-4.5 px-10 group shadow-2xl"
            >
                <Plus size={22} className="mr-2 group-hover:rotate-90 transition-transform duration-300" />
                <span className="tracking-widest font-black uppercase">NOUVEAU CAS</span>
            </button>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {cases
                    .filter((c) => filter === 'all' || c.status === filter)
                    .filter((c) => {
                        if (!searchQuery.trim()) return true;
                        const q = searchQuery.toLowerCase();
                        return (c.consultation_reason || '').toLowerCase().includes(q) || (c.patient_name || '').toLowerCase().includes(q) || (c.disease_id || '').toLowerCase().includes(q);
                    })
                    .map((c, idx) => (
                        <CaseCard
                            key={c.id || idx}
                            status={c.status}
                            id={`#${c.id}`}
                            title={c.consultation_reason || c.patient_name}
                            specialty={specialties.find(s => s.id === c.specialty_id)?.name || null}
                            difficulty={c.difficulty || 1}
                            modifiedAt={new Date(c.updated_at).toLocaleDateString()}
                            idx={idx}
                            onArchive={() => patchStatus(c.id, 'archived')}
                            onRestore={() => patchStatus(c.id, 'active')}
                            onEdit={() => handleEdit(c.id)}
                            onView={() => onViewCase && onViewCase(c.id)}
                        />
                    ))}
            </div>
        </div>
    );
};

export default CaseManagement;
