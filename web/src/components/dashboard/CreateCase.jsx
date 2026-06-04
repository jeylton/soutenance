import React, { useState, useEffect } from 'react';
import { REAL_AVATARS, resolveAvatarByValue, resolveAvatarProfile } from '../../assets/realAvatars';
import {
    ChevronLeft,
    Save,
    Plus,
    Check,
    Star,
    Trash2,
    Microscope,
    History,
    Brain,
    GraduationCap,
    Users,
    X,
    Sparkles,
    Loader2,
    RefreshCw,
    Wand2,
} from 'lucide-react';

const SectionHeader = ({ num, title, subtitle }) => (
    <div className="flex items-center space-x-4 mb-8">
        <div className="w-10 h-10 rounded-full bg-[#0D1B17] border border-[#1A2E28] flex items-center justify-center text-[#00C88C] font-black text-xs">
            {num}
        </div>
        <div>
            <h3 className="text-xl font-black text-white uppercase tracking-tight">{title}</h3>
            {subtitle && <p className="text-[10px] text-slate-500 font-bold uppercase tracking-widest">{subtitle}</p>}
        </div>
    </div>
);

const InputGroup = ({ label, children, className = "" }) => (
    <div className={`space-y-3 ${className}`}>
        <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] px-1">{label}</label>
        {children}
    </div>
);

const FALLBACK_AVATAR = REAL_AVATARS[0] || null;

const toStringArray = (value, fallback = ['']) => {
    if (Array.isArray(value)) return value;
    if (typeof value === 'string' && value.trim()) return [value.trim()];
    return fallback;
};

function AvatarThumb({ avatar, selected, onSelect }) {
    const [srcIndex, setSrcIndex] = useState(0);
    const candidates = [avatar.img, avatar.path].filter(Boolean);
    const src = candidates[srcIndex] || FALLBACK_AVATAR?.img || FALLBACK_AVATAR?.path || '';

    return (
        <div className="group cursor-pointer" onClick={onSelect}>
            <div className={`relative aspect-square rounded-2xl overflow-hidden border-2 transition-all duration-300 ${selected ? 'border-[#00C88C] shadow-[0_0_20px_rgba(0,200,140,0.3)]' : 'border-[#1A2E28] grayscale group-hover:grayscale-0 group-hover:border-[#00C88C]/40'}`}>
                <img
                    src={src}
                    alt={avatar.label}
                    className="w-full h-full object-cover"
                    onError={() => {
                        if (srcIndex < candidates.length - 1) {
                            setSrcIndex((v) => v + 1);
                        }
                    }}
                />
                {avatar.animated && <span className="absolute bottom-2 left-2 bg-black/60 text-xs text-white px-2 py-1 rounded">GIF</span>}
                {selected && (
                    <div className="absolute top-2 right-2 w-5 h-5 bg-[#00C88C] rounded-full flex items-center justify-center text-[#050C0A] shadow-lg">
                        <Check size={12} strokeWidth={4} />
                    </div>
                )}
            </div>
            <p className={`text-[9px] font-black uppercase tracking-widest text-center mt-3 ${selected ? 'text-[#00C88C]' : 'text-slate-600'}`}>
                {avatar.label}
            </p>
        </div>
    );
}

const CreateCase = ({ onBack, editData, presetSpecialtyId, presetSeason, presetEpisode }) => {
    const api = import.meta.env.VITE_API_URL || '';
    const isEdit = !!editData;
    const [specialties, setSpecialties] = useState([]);
    const initialSpecialty = (editData?.specialty_id ?? presetSpecialtyId ?? '');
    const [selectedSpecialty, setSelectedSpecialty] = useState(initialSpecialty ? String(initialSpecialty) : '');
    const [allCases, setAllCases] = useState([]);
    const initialSeason = Number(editData?.medical_history?.season) || Number(presetSeason) || null;
    const initialEpisode = Number(editData?.medical_history?.episode) || Number(presetEpisode) || null;
    const [assignedSeason, setAssignedSeason] = useState(initialSeason);
    const [assignedEpisode, setAssignedEpisode] = useState(initialEpisode);
    const initialAvatar = resolveAvatarByValue(editData?.avatar) || resolveAvatarProfile({
        age: editData?.medical_history?.age,
        gender: editData?.medical_history?.gender,
    });
    const [selectedAvatarPath, setSelectedAvatarPath] = useState(initialAvatar?.path || '');
    const [selectedVoiceId, setSelectedVoiceId] = useState(
        (editData?.medical_history?.eleven_voice_id || initialAvatar?.voiceId || '').toString(),
    );
    const [patientName, setPatientName] = useState(editData?.patient_name || '');
    const [patientAge, setPatientAge] = useState(editData?.medical_history?.age || '');
    const [patientGender, setPatientGender] = useState(editData?.medical_history?.gender || 'Masculin');
    const [consultationReason, setConsultationReason] = useState(editData?.consultation_reason || '');
    const [initialSymptoms, setInitialSymptoms] = useState(editData?.initial_symptoms || '');
    const [diagnosisFinal, setDiagnosisFinal] = useState(editData?.disease_id || editData?.logic_medicale || '');
    const [difficulty, setDifficulty] = useState(editData?.difficulty || 3);
    const [promptPatient, setPromptPatient] = useState(editData?.prompt_patient || '');
    const [promptTuteur, setPromptTuteur] = useState(editData?.prompt_tuteur || '');
    // Dynamic arrays
    const [antecedentsPerso, setAntecedentsPerso] = useState(
        toStringArray(editData?.medical_history?.antecedents?.perso, ['']),
    );
    const [familyPere, setFamilyPere] = useState(
        toStringArray(editData?.medical_history?.antecedents?.familiaux?.pere, ['']),
    );
    const [familyMere, setFamilyMere] = useState(
        toStringArray(editData?.medical_history?.antecedents?.familiaux?.mere, ['']),
    );
    const [allergies, setAllergies] = useState(
        toStringArray(editData?.medical_history?.allergies, ['']),
    );
    const [habits, setHabits] = useState(
        toStringArray(editData?.medical_history?.habits, ['']),
    );
    const [exams, setExams] = useState(editData?.case_exams?.length ? editData.case_exams.map(e => ({ name: e.name, result: e.result, is_relevant: e.is_relevant !== undefined ? e.is_relevant : true })) : [{ name: '', result: '', is_relevant: true }]);
    const [treatment, setTreatment] = useState(editData?.medical_history?.treatment?.length ? editData.medical_history.treatment : [{ medication: '', dosage: '', frequency: '', duration: '' }]);
    const [treatmentNotes, setTreatmentNotes] = useState(editData?.medical_history?.treatment_notes || '');
    const [saving, setSaving] = useState(false);
    const [generating, setGenerating] = useState(false);
    const [generated, setGenerated] = useState(!!editData);
    const [generatedDiagnosesBySpecialty, setGeneratedDiagnosesBySpecialty] = useState({});
    const [usedDiagnoses, setUsedDiagnoses] = useState([]);
    const [loadingUsed, setLoadingUsed] = useState(false);

    const normalizeDiagnosis = (value) =>
        String(value || '')
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, ' ')
            .trim();

    const seasonOfCase = (c) => {
        const n = Number(c?.medical_history?.season);
        return Number.isFinite(n) && n > 0 ? n : null;
    };

    const episodeOfCase = (c) => {
        const n = Number(c?.medical_history?.episode);
        return Number.isFinite(n) && n > 0 ? n : null;
    };

    const resolveNextSlot = (specialtyId, difficultyLevel) => {
        const sid = Number(specialtyId);
        const season = Number(difficultyLevel) || 1; // Saison = Difficulté (1 étoile → Saison 1, etc.)
        if (!Number.isFinite(sid) || sid <= 0) {
            return { season, episode: 1 };
        }

        const usedEpisodes = new Set();
        for (const c of allCases) {
            if (String(c?.specialty_id) !== String(sid)) continue;
            if (String(c?.status || '').toLowerCase() !== 'active') continue;
            const s = seasonOfCase(c);
            const e = episodeOfCase(c);
            if (s !== season || !e || e > 10) continue;
            usedEpisodes.add(e);
        }

        for (let e = 1; e <= 10; e += 1) {
            if (!usedEpisodes.has(e)) return { season, episode: e };
        }

        return { season, episode: 11 }; // 11 = saison complète
    };

    useEffect(() => {
        const profile = resolveAvatarByValue(selectedAvatarPath) || resolveAvatarProfile({ age: patientAge, gender: patientGender });
        if (!selectedAvatarPath && profile?.path) {
            setSelectedAvatarPath(profile.path);
        }
        if (profile?.voiceId) {
            setSelectedVoiceId(profile.voiceId);
        }
    }, [patientAge, patientGender, selectedAvatarPath]);

    useEffect(() => {
        fetch(`${api}/api/specialties`)
            .then(r => r.json())
            .then(d => setSpecialties(d.specialties || []))
            .catch(() => setSpecialties([]));
    }, []);

    useEffect(() => {
        fetch(`${api}/api/cases`)
            .then((r) => r.json())
            .then((d) => setAllCases(d.cases || []))
            .catch(() => setAllCases([]));
    }, [api]);

    // Charger les diagnostics déjà utilisés pour la spécialité sélectionnée
    useEffect(() => {
        if (!selectedSpecialty) { setUsedDiagnoses([]); return; }
        setLoadingUsed(true);
        fetch(`${api}/api/llm/used-diagnoses/${selectedSpecialty}`)
            .then(r => r.json())
            .then(d => setUsedDiagnoses(d.diagnoses || []))
            .catch(() => setUsedDiagnoses([]))
            .finally(() => setLoadingUsed(false));
    }, [api, selectedSpecialty]);

    useEffect(() => {
        if (!isEdit) return;
        setAssignedSeason(Number(editData?.medical_history?.season) || null);
        setAssignedEpisode(Number(editData?.medical_history?.episode) || null);
    }, [isEdit, editData]);

    useEffect(() => {
        if (isEdit) return;
        if (presetSeason && presetEpisode) return; // slot pré-assigné (Remplacer) → ne pas recalculer
        if (!selectedSpecialty) return;
        const next = resolveNextSlot(selectedSpecialty, difficulty);
        setAssignedSeason(next.season);
        setAssignedEpisode(next.episode);
    }, [isEdit, selectedSpecialty, difficulty, allCases, presetSeason, presetEpisode]);

    // Dynamic array helpers
    const addItem = (setter) => setter((prev) => [...prev, '']);
    const removeItem = (setter, idx) => setter((prev) => prev.filter((_, i) => i !== idx));
    const updateItem = (setter, idx, value) => setter((prev) => { const copy = [...prev]; copy[idx] = value; return copy; });

    const addExam = () => setExams([...exams, { name: '', result: '', is_relevant: true }]);
    const removeExam = (idx) => setExams(exams.filter((_, i) => i !== idx));
    const updateExam = (idx, field, value) => {
        const copy = exams.slice();
        copy[idx][field] = value;
        setExams(copy);
    };

    const filterEmpty = (arr) => arr.filter(v => v && v.trim());

    // ─── AI Generation ───
    const generateWithAI = async () => {
        if (!selectedSpecialty) {
            alert('Veuillez choisir une spécialité avant de générer');
            return;
        }
        const specName = specialties.find(s => s.id == selectedSpecialty)?.name || '';
        const specialtyKey = String(selectedSpecialty || specName || 'global');
        const localExcluded = generatedDiagnosesBySpecialty[specialtyKey] || [];

        const currentDiagnosis = (diagnosisFinal || '').trim();
        const excludedDiagnoses = currentDiagnosis
            ? Array.from(new Set([...localExcluded, currentDiagnosis]))
            : localExcluded;

        setGenerating(true);
        try {
            const res = await fetch(`${api}/api/llm/generate-case`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    specialty_name: specName,
                    specialty_id: selectedSpecialty ? Number(selectedSpecialty) : null,
                    difficulty,
                    excluded_diagnoses: excludedDiagnoses,
                }),
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error || 'Erreur IA');
            const c = data.case;
            const newDiagnosis = (c.diagnosis || '').trim();
            setPatientName(c.patient_name || '');
            setPatientAge(c.age || '');
            setPatientGender(c.gender || 'Masculin');
            setConsultationReason(c.consultation_reason || '');
            setInitialSymptoms(c.initial_symptoms || '');
            setDiagnosisFinal(c.diagnosis || '');
            setAntecedentsPerso(toStringArray(c.antecedents_perso, ['']));
            setFamilyPere(toStringArray(c.antecedents_familiaux_pere, ['']));
            setFamilyMere(toStringArray(c.antecedents_familiaux_mere, ['']));
            setAllergies(toStringArray(c.allergies, ['Néant']));
            setHabits(toStringArray(c.habits, ['']));
            setExams(c.exams?.length ? c.exams : [{ name: '', result: '' }]);
            setPromptPatient(c.prompt_patient || '');
            setPromptTuteur(c.prompt_tuteur || '');
            setTreatment(c.treatment?.length ? c.treatment : [{ medication: '', dosage: '', frequency: '', duration: '' }]);
            setTreatmentNotes(c.treatment_notes || '');
            const profile = resolveAvatarProfile({
                hint: c.avatar_hint || 'male_young',
                age: c.age,
                gender: c.gender,
            });
            if (profile?.path) setSelectedAvatarPath(profile.path);
            if (profile?.voiceId) setSelectedVoiceId(profile.voiceId);
            if (newDiagnosis) {
                setGeneratedDiagnosesBySpecialty((prev) => {
                    const existing = prev[specialtyKey] || [];
                    const existingSet = new Set(existing.map((d) => normalizeDiagnosis(d)).filter(Boolean));
                    const next = [...existing];
                    if (!existingSet.has(normalizeDiagnosis(newDiagnosis))) {
                        next.push(newDiagnosis);
                    }
                    return { ...prev, [specialtyKey]: next };
                });
            }
            setGenerated(true);
        } catch (e) {
            alert('Erreur de génération IA: ' + e.message);
        } finally {
            setGenerating(false);
        }
    };

    const payload = () => ({
        avatar: selectedAvatarPath,
        patient_id: patientAge ? `${patientAge}ans-${patientGender}` : null,
        patient_name: patientName,
        consultation_reason: consultationReason,
        initial_symptoms: initialSymptoms,
        medical_history: {
            season: Number(assignedSeason) || null,
            episode: Number(assignedEpisode) || null,
            level: Number(assignedEpisode) || null,
            antecedents: {
                perso: filterEmpty(antecedentsPerso),
                familiaux: {
                    pere: filterEmpty(familyPere),
                    mere: filterEmpty(familyMere),
                },
            },
            allergies: filterEmpty(allergies).length > 0 ? filterEmpty(allergies) : ['Néant'],
            habits: filterEmpty(habits),
            age: patientAge || null,
            gender: patientGender,
            eleven_voice_id: selectedVoiceId || null,
            tts_provider: selectedVoiceId ? 'elevenlabs' : 'native',
            treatment: treatment.filter(t => t.medication?.trim()),
            treatment_notes: treatmentNotes || null,
        },
        prompt_patient: promptPatient,
        prompt_tuteur: promptTuteur,
        logic_medicale: diagnosisFinal,
        difficulty,
        disease_id: diagnosisFinal || null,
        specialty_id: selectedSpecialty || null,
        exams: exams.filter(e => e.name),
    });

    const saveCase = async (status = 'draft') => {
        if (!patientName.trim() || !consultationReason.trim()) {
            alert('Générez d\'abord un cas avec l\'IA ou remplissez le nom du patient et le motif');
            return;
        }
        if (!selectedSpecialty) {
            alert('Veuillez choisir une spécialité avant de publier.');
            return;
        }
        if (!isEdit && (!assignedSeason || !assignedEpisode)) {
            alert('Saison ou épisode non assigné — réessayez après la sélection de la spécialité.');
            return;
        }
        setSaving(true);
        try {
            if (isEdit) {
                // UPDATE existing case
                const res = await fetch(`${api}/api/cases/${editData.id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ ...payload(), status }),
                });
                const data = await res.json();
                if (!res.ok) throw new Error(data.error || 'Erreur lors de la mise à jour');
                alert('Cas mis à jour avec succès !');
            } else {
                // CREATE new case
                const res = await fetch(`${api}/api/cases`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload()),
                });
                const data = await res.json();
                if (!res.ok) throw new Error(data.error || 'Erreur lors de la création du cas');
                if (status && data.id) {
                    await fetch(`${api}/api/cases/${data.id}/status`, {
                        method: 'PATCH',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ status }),
                    });
                }
                alert(status === 'active' ? 'Cas publié avec succès !' : 'Brouillon enregistré');
            }
            onBack();
        } catch (e) {
            alert(e.message);
        } finally {
            setSaving(false);
        }
    };

    return (
        <div className="animate-in fade-in slide-in-from-bottom-6 duration-700 pb-32">
            {/* Header */}
            <header className="flex items-center justify-between mb-12">
                <div className="flex items-center space-x-6">
                    <button onClick={onBack} className="p-3 bg-[#0D1B17] border border-[#1A2E28] rounded-2xl text-slate-400 hover:text-white transition-all shadow-xl">
                        <ChevronLeft size={24} />
                    </button>
                    <div>
                        <div className="flex items-center space-x-2 text-[10px] font-black text-slate-500 uppercase tracking-widest mb-1">
                            <span>Administration</span><span>/</span><span className="text-[#00C88C]">Cas Cliniques</span>
                        </div>
                        <h2 className="text-4xl font-black text-white tracking-tight">{isEdit ? 'Modifier le Cas' : 'Nouveau Cas Clinique — IA'}</h2>
                    </div>
                </div>
                <div className="flex items-center space-x-4">
                    <button disabled={saving} onClick={() => saveCase('draft')} className="px-8 py-4 rounded-2xl border border-[#1A2E28] text-slate-400 font-black uppercase text-[10px] tracking-widest hover:text-white hover:bg-[#11241E] transition-all disabled:opacity-40">
                        Brouillon
                    </button>
                    <button disabled={saving || (!generated && !isEdit)} onClick={() => saveCase('active')} className="btn-primary py-4 px-10 group shadow-[0_0_30px_rgba(0,200,140,0.3)] disabled:opacity-40">
                        <Save size={18} className="mr-2" />
                        <span className="font-black tracking-widest uppercase">{saving ? 'Publication...' : 'Publier'}</span>
                    </button>
                </div>
            </header>

            {/* ══════════ AI Generation Panel ══════════ */}
            <div className={`stat-card p-12 mb-12 bg-gradient-to-br ${generated ? 'from-[#00C88C]/10 to-[#0D1B17]' : 'from-[#1a0d2e] to-[#0D1B17]'} border-2 ${generated ? 'border-[#00C88C]/30' : 'border-purple-500/30'} transition-all duration-500`}>
                <div className="flex items-center justify-between mb-10">
                    <div className="flex items-center space-x-5">
                        <div className={`w-16 h-16 rounded-2xl flex items-center justify-center ${generated ? 'bg-[#00C88C]/20' : 'bg-purple-500/20'} transition-colors`}>
                            {generated ? <Check size={32} className="text-[#00C88C]" /> : <Wand2 size={32} className="text-purple-400" />}
                        </div>
                        <div>
                            <h2 className="text-2xl font-black text-white tracking-tight">
                                {generated ? 'Cas Généré par IA ✓' : 'Génération par Intelligence Artificielle'}
                            </h2>
                            <p className="text-sm text-slate-400 mt-1">
                                {generated ? 'Vous pouvez modifier les champs ci-dessous puis publier' : 'Choisissez la difficulté et la spécialité, l\'IA génère tout le reste'}
                            </p>
                        </div>
                    </div>
                    {generated && (
                        <button onClick={generateWithAI} disabled={generating} className="flex items-center space-x-2 px-6 py-3 bg-purple-500/10 border border-purple-500/30 rounded-2xl text-purple-400 hover:bg-purple-500/20 transition-all">
                            <RefreshCw size={16} className={generating ? 'animate-spin' : ''} />
                            <span className="text-[10px] font-black uppercase tracking-widest">Regénérer</span>
                        </button>
                    )}
                </div>
                <div className="grid grid-cols-1 lg:grid-cols-4 gap-8 items-end">
                    <div className="space-y-4">
                        <label className="block text-[10px] font-black text-slate-400 uppercase tracking-[0.3em]">Niveau de Difficulté</label>
                        <div className="flex items-center space-x-6 bg-[#050C0A] rounded-2xl p-6 border border-[#1A2E28]">
                            <div className="flex space-x-2">
                                {[1, 2, 3, 4, 5].map(star => (
                                    <button key={star} onClick={() => setDifficulty(star)} className="transition-transform hover:scale-125">
                                        <Star size={28} className={star <= difficulty ? "fill-[#00C88C] text-[#00C88C]" : "text-slate-800"} />
                                    </button>
                                ))}
                            </div>
                            <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">
                                {['Très facile', 'Facile', 'Moyen', 'Difficile', 'Expert'][difficulty - 1]}
                            </span>
                        </div>
                    </div>
                    <div className="space-y-4">
                        <label className="block text-[10px] font-black text-slate-400 uppercase tracking-[0.3em]">Spécialité Médicale</label>
                        <select value={selectedSpecialty} onChange={(e) => setSelectedSpecialty(e.target.value)} className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-6 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold appearance-none shadow-inner">
                            <option value="">— Choisir une spécialité —</option>
                            {specialties.map(sp => (
                                <option key={sp.id} value={sp.id}>{sp.name}</option>
                            ))}
                        </select>
                    </div>
                    <div className="space-y-4">
                        <label className="block text-[10px] font-black text-slate-400 uppercase tracking-[0.3em]">Saison</label>
                        <input
                            type="number"
                            value={assignedSeason || ''}
                            disabled
                            className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-6 px-6 text-sm text-slate-400 font-bold shadow-inner"
                        />
                        <p className="text-[10px] font-bold uppercase tracking-widest">
                            {assignedEpisode > 10
                                ? <span className="text-rose-400">Saison complète — 10/10 épisodes publiés</span>
                                : assignedEpisode
                                ? <span className="text-[#00C88C]">Épisode {assignedEpisode}/10 — Prochain disponible</span>
                                : <span className="text-slate-500">Choisir une spécialité pour calculer l'épisode</span>
                            }
                        </p>
                    </div>
                    <button onClick={generateWithAI} disabled={generating || !selectedSpecialty} className={`flex items-center justify-center space-x-3 py-6 px-8 rounded-2xl font-black uppercase text-sm tracking-widest transition-all disabled:opacity-40 ${generating ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30' : 'bg-gradient-to-r from-purple-600 to-[#00C88C] text-white shadow-[0_0_30px_rgba(147,51,234,0.3)] hover:shadow-[0_0_50px_rgba(147,51,234,0.5)] hover:scale-[1.02]'}`}>
                        {generating ? (<><Loader2 size={22} className="animate-spin" /><span>L'IA génère le cas...</span></>) : (<><Sparkles size={22} /><span>Générer avec l'IA</span></>)}
                    </button>
                </div>
                {generating && (
                    <div className="mt-8 flex items-center space-x-4 p-6 rounded-2xl bg-purple-500/5 border border-purple-500/20">
                        <div className="flex space-x-1">
                            {[0, 1, 2].map(i => (<div key={i} className="w-2 h-2 bg-purple-400 rounded-full animate-bounce" style={{ animationDelay: `${i * 0.15}s` }} />))}
                        </div>
                        <p className="text-sm text-purple-300">Création du patient, symptômes, examens et diagnostics...</p>
                    </div>
                )}
            </div>

            {/* ══════════ Generated Content ══════════ */}
            {(generated || isEdit) && (
            <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-500">
                <div className="flex items-center space-x-3 mb-4">
                    <Sparkles size={18} className="text-[#00C88C]" />
                    <h3 className="text-lg font-black text-white uppercase tracking-tight">Contenu Généré — Modifiable</h3>
                    <div className="flex-1 h-px bg-[#1A2E28]" />
                </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
                {/* Left Column */}
                <div className="space-y-12">
                    {/* Section 0: Avatar */}
                    <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                        <SectionHeader num="0" title="Choix de l'Avatar" />
                        <div className="grid grid-cols-3 gap-4">
                            {REAL_AVATARS.map((av, idx) => (
                                <AvatarThumb
                                    key={av.label + idx}
                                    avatar={av}
                                    selected={selectedAvatarPath === av.path}
                                    onSelect={() => {
                                        setSelectedAvatarPath(av.path);
                                        setSelectedVoiceId(av.voiceId || '');
                                    }}
                                />
                            ))}
                        </div>
                    </div>

                    {/* Section 1: ID Patient */}
                    <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                        <SectionHeader num="1" title="ID Patient" />
                        <div className="space-y-8">
                            <InputGroup label="Nom du patient / Alias">
                                <input value={patientName} onChange={(e) => setPatientName(e.target.value)} type="text" placeholder="ex: Jean Dupont" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                            </InputGroup>
                            <div className="grid grid-cols-2 gap-6">
                                <InputGroup label="Âge">
                                    <input value={patientAge} type="number" onChange={(e) => setPatientAge(e.target.value)} placeholder="ex: 45" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                                </InputGroup>
                                <InputGroup label="Genre">
                                    <select value={patientGender} onChange={(e) => setPatientGender(e.target.value)} className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold appearance-none shadow-inner">
                                        <option>Masculin</option>
                                        <option>Féminin</option>
                                        <option>Autre</option>
                                    </select>
                                </InputGroup>
                            </div>
                        </div>
                    </div>

                    {/* Section 2: Clinique */}
                    <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                        <SectionHeader num="2" title="Clinique" />
                        <div className="space-y-8">
                            <InputGroup label="Motif de Consultation">
                                <textarea value={consultationReason} onChange={(e) => setConsultationReason(e.target.value)} rows="3" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold resize-none shadow-inner" />
                            </InputGroup>
                            <InputGroup label="Symptômes Initiaux">
                                <textarea value={initialSymptoms} onChange={(e) => setInitialSymptoms(e.target.value)} rows="3" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold resize-none shadow-inner" />
                            </InputGroup>
                            <InputGroup label="Diagnostic Final">
                                <input value={diagnosisFinal} onChange={(e) => setDiagnosisFinal(e.target.value)} type="text" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                            </InputGroup>
                        </div>
                    </div>

                    {/* Section 3: Exams */}
                    <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                        <div className="flex items-center justify-between mb-10">
                            <SectionHeader num="3" title="Examens & Résultats" />
                            <button className="flex items-center space-x-2 px-4 py-2 bg-[#11241E] border border-[#1A2E28] rounded-xl text-[9px] font-black text-[#00C88C] uppercase tracking-widest hover:brightness-125 transition-all">
                                <Plus size={14} />
                                <span>Ajouter</span>
                            </button>
                        </div>

                        <div className="space-y-6">
                            {exams.map((exam, idx) => (
                                <div key={idx} className={`p-6 rounded-3xl bg-[#050C0A] border-2 relative group ${exam.is_relevant === false ? 'border-amber-500/30' : 'border-[#00C88C]/30'}`}>
                                    <button onClick={() => removeExam(idx)} className="absolute -top-3 -right-3 w-8 h-8 bg-rose-500/10 border border-rose-500/30 rounded-xl flex items-center justify-center text-rose-500 opacity-0 group-hover:opacity-100 transition-all hover:bg-rose-500 hover:text-white">
                                        <Trash2 size={16} />
                                    </button>
                                    {exam.is_relevant === false && (
                                        <span className="absolute -top-3 left-4 px-3 py-1 bg-amber-500/20 border border-amber-500/40 rounded-full text-[8px] font-black text-amber-400 uppercase tracking-widest">Leurre</span>
                                    )}
                                    {exam.is_relevant === true && (
                                        <span className="absolute -top-3 left-4 px-3 py-1 bg-emerald-500/20 border border-emerald-500/40 rounded-full text-[8px] font-black text-emerald-400 uppercase tracking-widest">Pertinent</span>
                                    )}
                                    <div className="flex items-center space-x-3 mb-6">
                                        <Microscope className={exam.is_relevant === false ? 'text-amber-500' : 'text-[#00C88C]'} size={20} />
                                        <input value={exam.name} onChange={(e) => updateExam(idx, 'name', e.target.value)} type="text" placeholder="Nom de l'examen (ex: NFS)" className="flex-1 bg-transparent border-none p-0 text-sm text-white focus:ring-0 font-bold" />
                                        <button onClick={() => updateExam(idx, 'is_relevant', !exam.is_relevant)} className={`px-3 py-1 rounded-lg text-[9px] font-black uppercase tracking-widest transition-all ${exam.is_relevant === false ? 'bg-amber-500/10 text-amber-400 hover:bg-emerald-500/10 hover:text-emerald-400' : 'bg-emerald-500/10 text-emerald-400 hover:bg-amber-500/10 hover:text-amber-400'}`}>
                                            {exam.is_relevant === false ? '→ Pertinent' : '→ Leurre'}
                                        </button>
                                    </div>
                                    <textarea value={exam.result} onChange={(e) => updateExam(idx, 'result', e.target.value)} rows="3" placeholder="Résultats détaillés..." className="w-full bg-transparent border-none p-0 text-sm text-slate-300 focus:ring-0 resize-none font-medium"></textarea>
                                </div>
                            ))}

                            <button onClick={addExam} className="w-full p-8 border-2 border-dashed border-[#1A2E28] rounded-[2.5rem] flex flex-col items-center justify-center text-slate-600 hover:border-[#00C88C]/20 hover:text-[#00C88C] transition-all group">
                                <div className="w-12 h-12 rounded-full border-2 border-dashed border-slate-700 flex items-center justify-center mb-4 group-hover:border-[#00C88C]/30 transition-all">
                                    <Plus size={24} />
                                </div>
                                <span className="text-[10px] font-black uppercase tracking-[0.2em]">Nouvel examen complémentaire</span>
                            </button>
                        </div>
                    </div>
                </div>

                {/* Right Column */}
                <div className="space-y-12">
                    {/* Section 4: History */}
                    <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                        <SectionHeader num="4" title="Historique du Patient" />
                        <div className="grid grid-cols-1 gap-8">
                            {/* Personal History */}
                            <div className="space-y-4">
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center space-x-3 text-[#00C88C]">
                                        <History size={16} />
                                        <span className="text-[10px] font-black uppercase tracking-[.2em]">Antécédents Personnels</span>
                                    </div>
                                    <button onClick={() => addItem(setAntecedentsPerso)} className="flex items-center space-x-1 text-[#00C88C] text-[9px] font-black uppercase tracking-widest hover:brightness-125">
                                        <Plus size={14} /><span>Ajouter</span>
                                    </button>
                                </div>
                                {antecedentsPerso.map((v, i) => (
                                    <div key={i} className="flex items-center gap-2">
                                        <input value={v} onChange={(e) => updateItem(setAntecedentsPerso, i, e.target.value)} type="text" placeholder="Pathologie, chirurgie..." className="flex-1 bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-4 px-5 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                                        {antecedentsPerso.length > 1 && (
                                            <button onClick={() => removeItem(setAntecedentsPerso, i)} className="p-2 text-rose-500 hover:bg-rose-500/10 rounded-xl transition-all"><X size={16} /></button>
                                        )}
                                    </div>
                                ))}
                            </div>

                            {/* Family History */}
                            <div className="space-y-4">
                                <div className="flex items-center space-x-3 text-[#00C88C]">
                                    <Users size={16} />
                                    <span className="text-[10px] font-black uppercase tracking-[.2em]">Antécédents Familiaux</span>
                                </div>
                                {/* Père */}
                                <div className="space-y-2">
                                    <div className="flex items-center justify-between">
                                        <span className="text-[9px] font-black text-slate-500 uppercase tracking-widest">PÈRE</span>
                                        <button onClick={() => addItem(setFamilyPere)} className="flex items-center space-x-1 text-slate-500 text-[9px] font-black uppercase tracking-widest hover:text-[#00C88C]">
                                            <Plus size={12} /><span>Ajouter</span>
                                        </button>
                                    </div>
                                    {familyPere.map((v, i) => (
                                        <div key={i} className="flex items-center gap-2">
                                            <input value={v} onChange={(e) => updateItem(setFamilyPere, i, e.target.value)} type="text" placeholder="Détails..." className="flex-1 bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-3 px-5 text-xs text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                                            {familyPere.length > 1 && (
                                                <button onClick={() => removeItem(setFamilyPere, i)} className="p-1 text-rose-500 hover:bg-rose-500/10 rounded-xl"><X size={14} /></button>
                                            )}
                                        </div>
                                    ))}
                                </div>
                                {/* Mère */}
                                <div className="space-y-2">
                                    <div className="flex items-center justify-between">
                                        <span className="text-[9px] font-black text-slate-500 uppercase tracking-widest">MÈRE</span>
                                        <button onClick={() => addItem(setFamilyMere)} className="flex items-center space-x-1 text-slate-500 text-[9px] font-black uppercase tracking-widest hover:text-[#00C88C]">
                                            <Plus size={12} /><span>Ajouter</span>
                                        </button>
                                    </div>
                                    {familyMere.map((v, i) => (
                                        <div key={i} className="flex items-center gap-2">
                                            <input value={v} onChange={(e) => updateItem(setFamilyMere, i, e.target.value)} type="text" placeholder="Détails..." className="flex-1 bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-3 px-5 text-xs text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                                            {familyMere.length > 1 && (
                                                <button onClick={() => removeItem(setFamilyMere, i)} className="p-1 text-rose-500 hover:bg-rose-500/10 rounded-xl"><X size={14} /></button>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            </div>

                            {/* Allergies */}
                            <div className="space-y-4">
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center space-x-2 text-rose-500">
                                        <History size={14} className="opacity-50" />
                                        <span className="text-[9px] font-black uppercase tracking-widest">Allergies</span>
                                    </div>
                                    <button onClick={() => addItem(setAllergies)} className="flex items-center space-x-1 text-rose-400 text-[9px] font-black uppercase tracking-widest hover:brightness-125">
                                        <Plus size={12} /><span>Ajouter</span>
                                    </button>
                                </div>
                                {allergies.map((v, i) => (
                                    <div key={i} className="flex items-center gap-2">
                                        <input value={v} onChange={(e) => updateItem(setAllergies, i, e.target.value)} type="text" placeholder="Médicament, substance..." className="flex-1 bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-3 px-5 text-xs text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                                        {allergies.length > 1 && (
                                            <button onClick={() => removeItem(setAllergies, i)} className="p-1 text-rose-500 hover:bg-rose-500/10 rounded-xl"><X size={14} /></button>
                                        )}
                                    </div>
                                ))}
                            </div>

                            {/* Habits */}
                            <div className="space-y-4">
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center space-x-2 text-blue-500">
                                        <History size={14} className="opacity-50" />
                                        <span className="text-[9px] font-black uppercase tracking-widest">Habitudes</span>
                                    </div>
                                    <button onClick={() => addItem(setHabits)} className="flex items-center space-x-1 text-blue-400 text-[9px] font-black uppercase tracking-widest hover:brightness-125">
                                        <Plus size={12} /><span>Ajouter</span>
                                    </button>
                                </div>
                                {habits.map((v, i) => (
                                    <div key={i} className="flex items-center gap-2">
                                        <input value={v} onChange={(e) => updateItem(setHabits, i, e.target.value)} type="text" placeholder="Tabac, Alcool, Sport..." className="flex-1 bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-3 px-5 text-xs text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                                        {habits.length > 1 && (
                                            <button onClick={() => removeItem(setHabits, i)} className="p-1 text-rose-500 hover:bg-rose-500/10 rounded-xl"><X size={14} /></button>
                                        )}
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* Section 5: Traitement */}
                    <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                        <SectionHeader num="5" title="Traitement Proposé" subtitle="Posologie & Dosage" />
                        <div className="space-y-6">
                            {treatment.map((t, idx) => (
                                <div key={idx} className="p-6 rounded-3xl bg-[#050C0A] border-2 border-emerald-500/20 relative group">
                                    {treatment.length > 1 && (
                                        <button onClick={() => setTreatment(treatment.filter((_, i) => i !== idx))} className="absolute -top-3 -right-3 w-8 h-8 bg-rose-500/10 border border-rose-500/30 rounded-xl flex items-center justify-center text-rose-500 opacity-0 group-hover:opacity-100 transition-all hover:bg-rose-500 hover:text-white">
                                            <Trash2 size={16} />
                                        </button>
                                    )}
                                    <div className="grid grid-cols-2 gap-4">
                                        <InputGroup label="Médicament (DCI)">
                                            <input value={t.medication || ''} onChange={(e) => { const c = [...treatment]; c[idx] = { ...c[idx], medication: e.target.value }; setTreatment(c); }} type="text" placeholder="ex: Amoxicilline" className="w-full bg-transparent border border-[#1A2E28] rounded-xl py-3 px-4 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold" />
                                        </InputGroup>
                                        <InputGroup label="Dosage">
                                            <input value={t.dosage || ''} onChange={(e) => { const c = [...treatment]; c[idx] = { ...c[idx], dosage: e.target.value }; setTreatment(c); }} type="text" placeholder="ex: 1g" className="w-full bg-transparent border border-[#1A2E28] rounded-xl py-3 px-4 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold" />
                                        </InputGroup>
                                        <InputGroup label="Fréquence / Voie">
                                            <input value={t.frequency || ''} onChange={(e) => { const c = [...treatment]; c[idx] = { ...c[idx], frequency: e.target.value }; setTreatment(c); }} type="text" placeholder="ex: 3x/jour PO" className="w-full bg-transparent border border-[#1A2E28] rounded-xl py-3 px-4 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold" />
                                        </InputGroup>
                                        <InputGroup label="Durée">
                                            <input value={t.duration || ''} onChange={(e) => { const c = [...treatment]; c[idx] = { ...c[idx], duration: e.target.value }; setTreatment(c); }} type="text" placeholder="ex: 7 jours" className="w-full bg-transparent border border-[#1A2E28] rounded-xl py-3 px-4 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold" />
                                        </InputGroup>
                                    </div>
                                </div>
                            ))}
                            <button onClick={() => setTreatment([...treatment, { medication: '', dosage: '', frequency: '', duration: '' }])} className="w-full p-6 border-2 border-dashed border-[#1A2E28] rounded-[2rem] flex items-center justify-center text-slate-600 hover:border-[#00C88C]/20 hover:text-[#00C88C] transition-all group">
                                <Plus size={18} className="mr-2" />
                                <span className="text-[10px] font-black uppercase tracking-widest">Ajouter un médicament</span>
                            </button>
                            <InputGroup label="Notes thérapeutiques (mesures complémentaires)">
                                <textarea value={treatmentNotes} onChange={(e) => setTreatmentNotes(e.target.value)} rows="3" placeholder="Mesures hygiéno-diététiques, surveillance, contre-indications..." className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-4 px-5 text-sm text-slate-300 focus:outline-none focus:border-[#00C88C]/40 font-bold resize-none shadow-inner" />
                            </InputGroup>
                        </div>
                    </div>

                    {/* Section 6: AI Prompts */}
                    <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050205]">
                        <SectionHeader num="5" title="Instructions IA" subtitle="Générées — Modifiables" />
                        <div className="space-y-8">
                            <div className="space-y-3">
                                <div className="flex items-center space-x-3 text-[#00C88C]"><Brain size={18} /><span className="text-[10px] font-black uppercase tracking-widest">Instructions Patient</span></div>
                                <textarea value={promptPatient} onChange={(e) => setPromptPatient(e.target.value)} rows="4" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-slate-300 focus:outline-none focus:border-[#00C88C]/40 font-bold resize-none shadow-inner" />
                            </div>
                            <div className="space-y-3">
                                <div className="flex items-center space-x-3 text-[#00C88C]"><GraduationCap size={18} /><span className="text-[10px] font-black uppercase tracking-widest">Instructions Tuteur</span></div>
                                <textarea value={promptTuteur} onChange={(e) => setPromptTuteur(e.target.value)} rows="4" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-slate-300 focus:outline-none focus:border-[#00C88C]/40 font-bold resize-none shadow-inner" />
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* Footer Floating Action */}
            <div className="fixed bottom-12 left-1/2 -translate-x-1/2 z-50">
                <button disabled={saving} onClick={() => saveCase('active')} className="btn-primary py-6 px-20 group shadow-[0_0_50px_rgba(0,210,140,0.4)] scale-110 disabled:opacity-40">
                    <Check size={24} className="mr-3" />
                    <span className="text-lg font-black tracking-widest uppercase">{saving ? 'Publication...' : 'Publier le cas clinique'}</span>
                </button>
            </div>
            </div>
            )}
        </div>
    );
};

export default CreateCase;
