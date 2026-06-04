import React, { useEffect, useMemo, useState } from 'react';
import { Search, Plus, Edit2, Eye, Star, Clock, RotateCcw, Trash2, ChevronLeft, RefreshCw, LayoutGrid, List } from 'lucide-react';

const CaseCard = ({ status, id, title, specialty, difficulty, modifiedAt, season, episode, idx, onRestore, onEdit, onView, onDelete, onReplace }) => {
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
                    {(Number(season) > 0 || Number(episode) > 0) && (
                        <span className="text-[9px] text-slate-300 font-black px-3 py-1.5 bg-[#050C0A] rounded-lg border border-[#1A2E28]">
                            S{Number(season) || 1}E{Number(episode) || 0}
                        </span>
                    )}
                    <span className="text-[9px] text-slate-600 font-bold px-3 py-1.5 bg-[#050C0A] rounded-lg border border-[#1A2E28]">ID: {id}</span>
                </div>
                <div className="flex space-x-1.5 shadow-2xl">
                    {isArchive ? (
                        <>
                            <button onClick={onRestore} title="Restaurer" className="p-2.5 bg-[#11241E] text-slate-400 hover:text-[#00C88C] rounded-xl border border-[#1A2E28] transition-all">
                                <RotateCcw size={16} />
                            </button>
                            <button onClick={onView} title="Voir" className="p-2.5 bg-[#11241E] text-slate-400 hover:text-white rounded-xl border border-[#1A2E28] transition-all">
                                <Eye size={16} />
                            </button>
                            <button onClick={onDelete} title="Supprimer définitivement" className="p-2.5 bg-[#11241E] text-slate-400 hover:text-rose-500 rounded-xl border border-[#1A2E28] transition-all">
                                <Trash2 size={16} />
                            </button>
                        </>
                    ) : (
                        <>
                            <button onClick={onEdit} title="Modifier" className="p-2.5 bg-[#11241E] text-slate-400 hover:text-[#00C88C] rounded-xl border border-[#1A2E28] transition-all">
                                <Edit2 size={16} />
                            </button>
                            <button onClick={onView} title="Voir" className="p-2.5 bg-[#11241E] text-slate-400 hover:text-white rounded-xl border border-[#1A2E28] transition-all">
                                <Eye size={16} />
                            </button>
                            <button onClick={onReplace} title="Remplacer par un nouveau cas IA" className="p-2.5 bg-[#11241E] text-slate-400 hover:text-purple-400 rounded-xl border border-[#1A2E28] transition-all">
                                <RefreshCw size={16} />
                            </button>
                            <button onClick={onDelete} title="Supprimer définitivement" className="p-2.5 bg-[#11241E] text-slate-400 hover:text-rose-500 rounded-xl border border-[#1A2E28] transition-all">
                                <Trash2 size={16} />
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

// ── Composant Vue Carte Saisons ────────────────────────────────────────────────
const SeasonMap = ({ cases, specialtyId, specialties, onCreateNew, onEdit, onView, onDelete, onReplace }) => {
    const SEASONS = 5;
    const EPISODES = 10;

    const diffLabels = ['Très facile', 'Facile', 'Moyen', 'Difficile', 'Expert'];
    const diffColors = ['#22c55e', '#84cc16', '#f59e0b', '#ef4444', '#a855f7'];

    const getCaseForSlot = (season, episode) =>
        cases.find(c =>
            String(c.specialty_id) === String(specialtyId) &&
            Number(c.medical_history?.season) === season &&
            Number(c.medical_history?.episode) === episode
        );

    const totalPublished = cases.filter(c =>
        String(c.specialty_id) === String(specialtyId) && c.status === 'active'
    ).length;

    return (
        <div className="space-y-6">
            {/* Résumé */}
            <div className="flex items-center space-x-4 p-4 bg-[#0D1B17] rounded-2xl border border-[#1A2E28]">
                <div className="w-10 h-10 rounded-xl bg-[#00C88C]/10 border border-[#00C88C]/20 flex items-center justify-center text-[#00C88C]">
                    <LayoutGrid size={18} />
                </div>
                <div>
                    <p className="text-white font-black">{totalPublished} / {SEASONS * EPISODES} épisodes publiés</p>
                    <p className="text-[10px] text-slate-500 font-bold uppercase tracking-widest">{SEASONS} saisons × {EPISODES} épisodes</p>
                </div>
            </div>

            {/* Grille saisons */}
            {Array.from({ length: SEASONS }, (_, si) => {
                const season = si + 1;
                const seasonCases = cases.filter(c =>
                    String(c.specialty_id) === String(specialtyId) &&
                    Number(c.medical_history?.season) === season
                );
                const publishedCount = seasonCases.filter(c => c.status === 'active').length;

                return (
                    <div key={season} className="stat-card p-6">
                        {/* Header saison */}
                        <div className="flex items-center justify-between mb-5">
                            <div className="flex items-center space-x-3">
                                <div className="flex space-x-1">
                                    {[...Array(season)].map((_, i) => (
                                        <Star key={i} size={14} className="fill-[#00C88C] text-[#00C88C]" />
                                    ))}
                                    {[...Array(SEASONS - season)].map((_, i) => (
                                        <Star key={i} size={14} className="text-slate-800" />
                                    ))}
                                </div>
                                <span className="text-white font-black text-sm">Saison {season}</span>
                                <span className="text-[10px] text-slate-500 font-bold">{diffLabels[si]}</span>
                            </div>
                            <div className="flex items-center space-x-2">
                                <span className="text-[10px] font-black px-2 py-1 rounded-lg"
                                    style={{ color: diffColors[si], background: diffColors[si] + '15' }}>
                                    {publishedCount}/{EPISODES}
                                </span>
                                {/* Barre de progression */}
                                <div className="w-24 h-1.5 bg-[#1A2E28] rounded-full overflow-hidden">
                                    <div className="h-full rounded-full transition-all duration-500"
                                        style={{ width: `${(publishedCount / EPISODES) * 100}%`, backgroundColor: diffColors[si] }} />
                                </div>
                            </div>
                        </div>

                        {/* Grille épisodes */}
                        <div className="grid grid-cols-5 gap-3 md:grid-cols-10">
                            {Array.from({ length: EPISODES }, (_, ei) => {
                                const episode = ei + 1;
                                const c = getCaseForSlot(season, episode);

                                if (!c) {
                                    return (
                                        <button key={episode}
                                            onClick={() => onCreateNew && onCreateNew(specialtyId, season, episode)}
                                            className="aspect-square rounded-xl border-2 border-dashed border-[#1A2E28] flex flex-col items-center justify-center text-slate-700 hover:border-[#00C88C]/40 hover:text-[#00C88C] transition-all group">
                                            <Plus size={14} className="mb-1" />
                                            <span className="text-[8px] font-black">E{episode}</span>
                                        </button>
                                    );
                                }

                                const isActive = c.status === 'active';
                                const isArchived = c.status === 'archived';

                                return (
                                    <div key={episode}
                                        className={`aspect-square rounded-xl border-2 flex flex-col items-center justify-center relative group cursor-pointer transition-all
                                            ${isActive ? 'border-[#00C88C]/40 bg-[#00C88C]/5 hover:border-[#00C88C]' : ''}
                                            ${isArchived ? 'border-[#1A2E28] bg-[#050C0A] opacity-50' : ''}
                                            ${c.status === 'draft' ? 'border-amber-500/30 bg-amber-500/5 hover:border-amber-500' : ''}
                                        `}>
                                        <span className={`text-[8px] font-black mb-0.5 ${isActive ? 'text-[#00C88C]' : 'text-slate-500'}`}>
                                            E{episode}
                                        </span>
                                        <span className={`text-[7px] font-bold ${isActive ? 'text-[#00C88C]/70' : 'text-slate-600'}`}>
                                            {isActive ? '✓' : isArchived ? '🗄' : '~'}
                                        </span>
                                        {/* Actions au survol */}
                                        <div className="absolute inset-0 rounded-xl bg-black/80 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1">
                                            <button onClick={() => onView && onView(c.id)} className="p-1 text-white hover:text-[#00C88C]" title="Voir">
                                                <Eye size={10} />
                                            </button>
                                            <button onClick={() => onEdit && onEdit(c.id)} className="p-1 text-white hover:text-[#00C88C]" title="Modifier">
                                                <Edit2 size={10} />
                                            </button>
                                            <button onClick={() => onReplace && onReplace({ id: c.id, season, episode })} className="p-1 text-white hover:text-purple-400" title="Remplacer">
                                                <RefreshCw size={10} />
                                            </button>
                                            <button onClick={() => onDelete && onDelete(c.id)} className="p-1 text-white hover:text-rose-400" title="Supprimer">
                                                <Trash2 size={10} />
                                            </button>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                );
            })}
        </div>
    );
};

const CaseManagement = ({ onCreateNew, onViewCase, onEditCase }) => {
    const rawApi = (import.meta.env.VITE_API_URL || 'http://localhost:5000').trim().replace(/\/+$/, '');
    const apiRoot = rawApi.toLowerCase().endsWith('/api') ? rawApi : `${rawApi}/api`;
    const [cases, setCases] = useState([]);
    const [specialties, setSpecialties] = useState([]);
    const [selectedSpecialtyId, setSelectedSpecialtyId] = useState('');
    const [filter, setFilter] = useState('all');
    const [searchQuery, setSearchQuery] = useState('');
    const [viewMode, setViewMode] = useState('map'); // 'map' | 'list'

    const loadCases = () => {
        fetch(`${apiRoot}/cases`)
            .then((res) => res.json())
            .then((data) => setCases(data.cases || []))
            .catch(() => setCases([]));
    };
    useEffect(() => {
        loadCases();
        fetch(`${apiRoot}/specialties`)
            .then(r => r.json())
            .then(d => setSpecialties(d.specialties || []))
            .catch(() => {});
    }, [apiRoot]);

    const selectedSpecialty = useMemo(() => {
        if (!selectedSpecialtyId) return null;
        return specialties.find((s) => String(s.id) === String(selectedSpecialtyId)) || null;
    }, [specialties, selectedSpecialtyId]);

    const casesForSelectedSpecialty = useMemo(() => {
        if (!selectedSpecialtyId) return [];
        return cases.filter((c) => String(c.specialty_id) === String(selectedSpecialtyId));
    }, [cases, selectedSpecialtyId]);

    const seasonOfCase = (c) => {
        const n = Number(c?.medical_history?.season);
        return Number.isFinite(n) && n > 0 ? n : null;
    };

    const episodeOfCase = (c) => {
        const n = Number(c?.medical_history?.episode);
        return Number.isFinite(n) && n > 0 ? n : null;
    };

    const fetchJson = async (url, options) => {
        const res = await fetch(url, options);
        const contentType = res.headers.get('content-type') || '';
        if (contentType.includes('application/json')) {
            const data = await res.json();
            if (!res.ok) throw new Error(data?.error || `Erreur API (${res.status})`);
            return data;
        }
        const raw = await res.text();
        throw new Error(`Réponse non JSON (${res.status}): ${(raw || '').slice(0, 120)}`);
    };

    const patchStatus = async (id, status) => {
        await fetch(`${apiRoot}/cases/${id}/status`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status }),
        });
        loadCases();
    };

    const handleEdit = async (caseId) => {
        try {
            const res = await fetch(`${apiRoot}/cases/${caseId}`);
            const data = await res.json();
            if (data.case && onEditCase) {
                onEditCase(data.case);
            }
        } catch (e) {
            console.error('Failed to load case for edit:', e);
        }
    };

    const handleDelete = async (caseId) => {
        if (!window.confirm('Supprimer définitivement ce cas clinique ? Cette action est irréversible.')) return;
        try {
            await fetch(`${apiRoot}/cases/${caseId}`, { method: 'DELETE' });
            loadCases();
        } catch (e) {
            alert('Erreur lors de la suppression : ' + e.message);
        }
    };

    const handleReplace = async (caseItem) => {
        if (!window.confirm(`Remplacer ce cas (S${caseItem.season}E${caseItem.episode}) ? Il sera supprimé et vous pourrez générer un nouveau cas IA à sa place.`)) return;
        try {
            await fetch(`${apiRoot}/cases/${caseItem.id}`, { method: 'DELETE' });
            loadCases();
            // Ouvrir CreateCase avec la spécialité + le slot pré-assigné
            if (onCreateNew) onCreateNew(selectedSpecialtyId, caseItem.season, caseItem.episode);
        } catch (e) {
            alert('Erreur lors du remplacement : ' + e.message);
        }
    };

    if (!selectedSpecialtyId) {
        return (
            <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-8">
                <div className="stat-card p-8">
                    <h3 className="text-2xl font-black text-white tracking-tight mb-2">Choisir une spécialité</h3>
                    <p className="text-sm text-slate-400">Sélectionnez une spécialité pour gérer ses cas.</p>
                </div>

                {specialties.length === 0 ? (
                    <div className="stat-card p-8 text-slate-400">Aucune spécialité trouvée.</div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                        {specialties.map((sp) => {
                            const specCases = cases.filter((c) => String(c.specialty_id) === String(sp.id));
                            const activeCount = specCases.filter((c) => c.status === 'active').length;
                            const draftCount = specCases.filter((c) => c.status === 'draft').length;
                            const archivedCount = specCases.filter((c) => c.status === 'archived').length;
                            return (
                                <button
                                    key={sp.id}
                                    onClick={() => {
                                        setSelectedSpecialtyId(String(sp.id));
                                        setFilter('all');
                                        setSearchQuery('');
                                    }}
                                    className="stat-card p-8 text-left hover:border-[#00C88C]/40 transition-all"
                                >
                                    <p className="text-[10px] text-[#00C88C] font-black uppercase tracking-[0.2em] mb-2">Spécialité</p>
                                    <p className="text-2xl font-black text-white mb-6">{sp.name}</p>
                                    <div className="grid grid-cols-3 gap-3">
                                        <div className="p-3 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                                            <p className="text-[9px] uppercase tracking-widest text-slate-500 font-black">Actifs</p>
                                            <p className="text-lg font-black text-white">{activeCount}</p>
                                        </div>
                                        <div className="p-3 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                                            <p className="text-[9px] uppercase tracking-widest text-slate-500 font-black">Brouillons</p>
                                            <p className="text-lg font-black text-white">{draftCount}</p>
                                        </div>
                                        <div className="p-3 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                                            <p className="text-[9px] uppercase tracking-widest text-slate-500 font-black">Archivés</p>
                                            <p className="text-lg font-black text-white">{archivedCount}</p>
                                        </div>
                                    </div>
                                </button>
                            );
                        })}
                    </div>
                )}
            </div>
        );
    }

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-8">
            <div className="flex flex-wrap items-center justify-between gap-4">
                <button
                    onClick={() => setSelectedSpecialtyId('')}
                    className="inline-flex items-center gap-2 px-6 py-3 rounded-2xl border border-[#1A2E28] text-slate-400 font-black uppercase text-[10px] tracking-widest hover:text-white hover:bg-[#11241E] transition-all"
                >
                    <ChevronLeft size={16} />
                    Spécialités
                </button>
                <div className="min-w-[240px]">
                    <p className="text-[10px] text-slate-500 font-black uppercase tracking-[0.2em]">Spécialité sélectionnée</p>
                    <p className="text-2xl font-black text-white">{selectedSpecialty?.name || '—'}</p>
                </div>
            </div>

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

            <div className="flex items-center justify-between">
                <button
                    onClick={() => onCreateNew && onCreateNew(selectedSpecialtyId)}
                    className="btn-primary py-4 px-8 group shadow-2xl"
                >
                    <Plus size={20} className="mr-2 group-hover:rotate-90 transition-transform duration-300" />
                    <span className="tracking-widest font-black uppercase text-sm">Nouveau Cas</span>
                </button>

                {/* Toggle vue */}
                <div className="flex items-center bg-[#081310] p-1.5 rounded-2xl border border-[#1A2E28]">
                    <button onClick={() => setViewMode('map')}
                        className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all
                            ${viewMode === 'map' ? 'bg-[#00C88C] text-[#050C0A]' : 'text-slate-500 hover:text-[#00C88C]'}`}>
                        <LayoutGrid size={14} />
                        <span>Carte</span>
                    </button>
                    <button onClick={() => setViewMode('list')}
                        className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all
                            ${viewMode === 'list' ? 'bg-[#00C88C] text-[#050C0A]' : 'text-slate-500 hover:text-[#00C88C]'}`}>
                        <List size={14} />
                        <span>Liste</span>
                    </button>
                </div>
            </div>

            {/* Vue Carte Saisons */}
            {viewMode === 'map' && (
                <SeasonMap
                    cases={cases}
                    specialtyId={selectedSpecialtyId}
                    specialties={specialties}
                    onCreateNew={onCreateNew}
                    onEdit={(id) => handleEdit(id)}
                    onView={(id) => onViewCase && onViewCase(id)}
                    onDelete={(id) => handleDelete(id)}
                    onReplace={(item) => handleReplace(item)}
                />
            )}

            {/* Vue Liste (existante) */}
            {viewMode === 'list' && <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {cases
                    .filter((c) => String(c.specialty_id) === String(selectedSpecialtyId))
                    .filter((c) => filter === 'all' || c.status === filter)
                    .filter((c) => {
                        if (!searchQuery.trim()) return true;
                        const q = searchQuery.toLowerCase();
                        return (c.consultation_reason || '').toLowerCase().includes(q) || (c.patient_name || '').toLowerCase().includes(q) || (c.disease_id || '').toLowerCase().includes(q);
                    })
                    .sort((a, b) => {
                        const sa = seasonOfCase(a) || 0;
                        const sb = seasonOfCase(b) || 0;
                        if (sa !== sb) return sa - sb;
                        const ea = episodeOfCase(a) || 0;
                        const eb = episodeOfCase(b) || 0;
                        if (ea !== eb) return ea - eb;
                        const ta = Date.parse(String(a?.updated_at || '')) || 0;
                        const tb = Date.parse(String(b?.updated_at || '')) || 0;
                        return tb - ta;
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
                            season={seasonOfCase(c)}
                            episode={episodeOfCase(c)}
                            idx={idx}
                            onRestore={() => patchStatus(c.id, 'active')}
                            onEdit={() => handleEdit(c.id)}
                            onView={() => onViewCase && onViewCase(c.id)}
                            onDelete={() => handleDelete(c.id)}
                            onReplace={() => handleReplace({ id: c.id, season: seasonOfCase(c), episode: episodeOfCase(c) })}
                        />
                    ))}
            </div>}
        </div>
    );
};

export default CaseManagement;
