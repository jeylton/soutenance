import React, { useEffect, useState } from 'react';
import {
    ChevronLeft,
    Save,
    FileText,
    Bold,
    Italic,
    List,
    Link2,
    Info,
    Sparkles,
    Loader2,
    RefreshCw,
    Wand2,
    Check,
    BookOpen,
} from 'lucide-react';

const REQUIRED_SVT_SECTIONS = [
    '1. TITRE DU COURS :',
    '2. PROBLEMATIQUE SVT :',
    '3. OBJECTIFS D\'APPRENTISSAGE :',
    '4. PREREQUIS :',
    '5. VOCABULAIRE CLE :',
    '6. RAPPELS ANATOMIE ET PHYSIOLOGIE :',
    '7. MECANISME DE LA MALADIE (PHYSIOPATHOLOGIE) :',
    '8. CAUSES ET FACTEURS DE RISQUE :',
    '9. SIGNES CLINIQUES :',
    '10. EXAMENS ET INTERPRETATION GENERALE :',
    '11. PRINCIPES DE PRISE EN CHARGE (SANS RESOUDRE LE CAS) :',
    '12. PREVENTION ET SURVEILLANCE :',
    '13. ERREURS FREQUENTES :',
];

const normalizeText = (value) =>
    String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toUpperCase();

const validateSvtContent = (rawContent) => {
    const normalized = normalizeText(rawContent);
    const missing = [];
    let cursor = 0;

    REQUIRED_SVT_SECTIONS.forEach((section) => {
        const normalizedSection = normalizeText(section);
        const idx = normalized.indexOf(normalizedSection, cursor);
        if (idx === -1) {
            missing.push(section);
        } else {
            cursor = idx + normalizedSection.length;
        }
    });

    return {
        ok: missing.length === 0,
        missing,
    };
};

const countSvtSectionsPresentInOrder = (rawContent) => {
    const normalized = normalizeText(rawContent);
    let cursor = 0;
    let count = 0;

    REQUIRED_SVT_SECTIONS.forEach((section) => {
        const normalizedSection = normalizeText(section);
        const idx = normalized.indexOf(normalizedSection, cursor);
        if (idx !== -1) {
            count += 1;
            cursor = idx + normalizedSection.length;
        }
    });

    return count;
};

const CreateCourse = ({ onBack, editData }) => {
    const api = import.meta.env.VITE_API_URL;
    const isEditing = !!editData;
    const [title, setTitle] = useState(editData?.title || '');
    const [specialtyId, setSpecialtyId] = useState(editData?.specialty_id ? String(editData.specialty_id) : '');
    const [content, setContent] = useState(editData?.content || '');
    const [pdfUrl, setPdfUrl] = useState('');
    const [caseId, setCaseId] = useState(editData?.case_id ? String(editData.case_id) : '');
    const [cases, setCases] = useState([]);
    const [specialties, setSpecialties] = useState([]);
    const [saving, setSaving] = useState(false);
    const [generating, setGenerating] = useState(false);
    const [generated, setGenerated] = useState(isEditing);
    const [references, setReferences] = useState(() => {
        if (editData?.pdf_url && editData.pdf_url.startsWith('REF::')) {
            try { return JSON.parse(editData.pdf_url.substring(5)); } catch { return []; }
        }
        return [];
    });

    useEffect(() => {
        if (editData?.pdf_url && !editData.pdf_url.startsWith('REF::') && editData.pdf_url.trim()) {
            setPdfUrl(editData.pdf_url);
        }
    }, [editData]);

    useEffect(() => {
        fetch(`${api}/api/cases`)
            .then((res) => res.json())
            .then((data) => setCases((data.cases || []).filter(c => c.status === 'active')))
            .catch(() => setCases([]));
        fetch(`${api}/api/specialties`)
            .then((res) => res.json())
            .then((data) => setSpecialties(data.specialties || []))
            .catch(() => setSpecialties([]));
    }, []);

    // ─── AI Generation ───
    const generateWithAI = async () => {
        if (!caseId) {
            alert('Veuillez sélectionner un cas clinique');
            return;
        }
        setGenerating(true);
        try {
            const res = await fetch(`${api}/api/llm/generate-course`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ case_id: Number(caseId) }),
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error || 'Erreur IA');
            const c = data.course;
            setTitle(c.title || '');
            setContent(c.content || '');
            setReferences(c.references || []);
            // Auto-set specialty from case
            const selectedCase = cases.find(cs => cs.id == caseId);
            if (selectedCase?.specialty_id) setSpecialtyId(String(selectedCase.specialty_id));
            setGenerated(true);
        } catch (e) {
            alert('Erreur de génération IA: ' + e.message);
        } finally {
            setGenerating(false);
        }
    };

    const publishCourse = async () => {
        if (!isEditing && (!generated || !caseId)) {
            alert('Veuillez générer le cours avec l\'IA avant publication');
            return;
        }
        if (!title.trim()) {
            alert('Veuillez générer un contenu de quiz valide');
            return;
        }

        const svtValidation = validateSvtContent(content);
        if (!svtValidation.ok) {
            alert(`Format SVT incomplet. Sections manquantes: ${svtValidation.missing.join(' | ')}`);
            return;
        }

        if (!pdfUrl && references.length < 5) {
            alert('Ajoutez au moins 5 ressources externes fiables (ou un lien PDF) avant publication.');
            return;
        }

        setSaving(true);
        try {
            // Build pdf_url: either a direct URL or JSON-encoded references
            let finalPdfUrl = pdfUrl || null;
            if (references.length > 0 && !pdfUrl) {
                finalPdfUrl = 'REF::' + JSON.stringify(references);
            }
            const url = isEditing ? `${api}/api/courses/${editData.id}` : `${api}/api/courses`;
            const method = isEditing ? 'PATCH' : 'POST';
            const res = await fetch(url, {
                method,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    title,
                    content,
                    pdf_url: finalPdfUrl,
                    case_id: caseId ? Number(caseId) : null,
                    specialty_id: specialtyId ? Number(specialtyId) : null,
                    status: 'published',
                }),
            });
            const data = await res.json();
            if (!res.ok) throw new Error(data.error || (isEditing ? 'Erreur lors de la modification du cours' : 'Erreur lors de la création du cours'));
            alert(isEditing ? 'Quiz modifié avec succès !' : 'Quiz publié avec succès !');
            onBack();
        } catch (e) {
            alert(e.message);
        } finally {
            setSaving(false);
        }
    };

    const svtValidationPreview = validateSvtContent(content);
    const svtSectionsProgress = countSvtSectionsPresentInOrder(content);

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
                            <span>Administration</span><span>/</span><span className="text-[#00C88C]">Gestion des Quiz</span>
                        </div>
                        <h2 className="text-4xl font-black text-white tracking-tight">{isEditing ? 'Modifier le Quiz' : 'Nouveau Quiz — IA'}</h2>
                    </div>
                </div>
                <div className="flex items-center space-x-4">
                    <button onClick={publishCourse} disabled={saving || (!generated && !isEditing)} className="btn-primary py-4 px-10 group shadow-[0_0_30px_rgba(0,200,140,0.3)] disabled:opacity-40">
                        <Save size={18} className="mr-2" />
                        <span className="font-black tracking-widest uppercase">{saving ? 'Publication...' : isEditing ? 'Sauvegarder' : 'Publier'}</span>
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
                                {generated ? 'Quiz Généré par IA ✓' : 'Génération par Intelligence Artificielle'}
                            </h2>
                            <p className="text-sm text-slate-400 mt-1">
                                {generated ? 'Vous pouvez modifier le contenu ci-dessous puis publier' : 'Sélectionnez un cas clinique publié, l\'IA génère un quiz complet'}
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

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-end">
                    {/* Case selector */}
                    <div className="lg:col-span-2 space-y-4">
                        <label className="block text-[10px] font-black text-slate-400 uppercase tracking-[0.3em]">Cas Clinique de Référence</label>
                        <select value={caseId} onChange={(e) => setCaseId(e.target.value)} className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-6 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold appearance-none shadow-inner">
                            <option value="">— Sélectionner un cas clinique publié —</option>
                            {cases.map(c => (
                                <option key={c.id} value={c.id}>Cas #{c.id} — {c.patient_name} {c.disease_id ? `(${c.disease_id})` : ''}</option>
                            ))}
                        </select>
                        {caseId && (
                            <div className="flex items-center space-x-2 text-slate-500 px-2">
                                <BookOpen size={14} />
                                <p className="text-[10px] font-medium">L'IA va analyser ce cas et créer un quiz pédagogique basé sur sa maladie</p>
                            </div>
                        )}
                    </div>

                    {/* Generate Button */}
                    <button onClick={generateWithAI} disabled={generating || !caseId} className={`flex items-center justify-center space-x-3 py-6 px-8 rounded-2xl font-black uppercase text-sm tracking-widest transition-all disabled:opacity-40 ${generating ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30' : 'bg-gradient-to-r from-purple-600 to-[#00C88C] text-white shadow-[0_0_30px_rgba(147,51,234,0.3)] hover:shadow-[0_0_50px_rgba(147,51,234,0.5)] hover:scale-[1.02]'}`}>
                        {generating ? (<><Loader2 size={22} className="animate-spin" /><span>Génération...</span></>) : (<><Sparkles size={22} /><span>Générer le quiz</span></>)}
                    </button>
                </div>

                {generating && (
                    <div className="mt-8 flex items-center space-x-4 p-6 rounded-2xl bg-purple-500/5 border border-purple-500/20">
                        <div className="flex space-x-1">
                            {[0, 1, 2].map(i => (<div key={i} className="w-2 h-2 bg-purple-400 rounded-full animate-bounce" style={{ animationDelay: `${i * 0.15}s` }} />))}
                        </div>
                        <p className="text-sm text-purple-300">Analyse du cas clinique et génération du quiz...</p>
                    </div>
                )}
            </div>

            {/* ══════════ Generated Content ══════════ */}
            {generated && (
            <div className="max-w-6xl space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-500">
                <div className="flex items-center space-x-3 mb-4">
                    <Sparkles size={18} className="text-[#00C88C]" />
                    <h3 className="text-lg font-black text-white uppercase tracking-tight">Contenu Généré — Modifiable</h3>
                    <div className="flex-1 h-px bg-[#1A2E28]" />
                </div>

                {/* Title + Specialty */}
                <div className="stat-card p-12 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
                        <div className="lg:col-span-2 space-y-4">
                            <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Titre du quiz</label>
                            <input value={title} onChange={(e) => setTitle(e.target.value)} type="text" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                        </div>
                        <div className="space-y-4">
                            <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Spécialité</label>
                            <select value={specialtyId} onChange={(e) => setSpecialtyId(e.target.value)} className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-8 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold appearance-none shadow-inner">
                                <option value="">Aucune</option>
                                {specialties.map((s) => (
                                    <option key={s.id} value={s.id}>{s.name}</option>
                                ))}
                            </select>
                        </div>
                    </div>
                </div>

                {/* Content */}
                <div className="stat-card p-0 overflow-hidden bg-[#0D1B17] border border-[#1A2E28]">
                    <div className="flex items-center justify-between p-6 border-b border-[#1A2E28] bg-[#11241E]/50">
                        <div className="flex items-center space-x-6 text-slate-500">
                            <button className="hover:text-[#00C88C] transition-colors"><Bold size={18} /></button>
                            <button className="hover:text-[#00C88C] transition-colors"><Italic size={18} /></button>
                            <button className="hover:text-[#00C88C] transition-colors"><List size={18} /></button>
                            <button className="hover:text-[#00C88C] transition-colors"><Link2 size={18} /></button>
                        </div>
                        <div className="flex items-center gap-3">
                            <span className={`px-3 py-1 rounded-full text-[9px] font-black uppercase tracking-widest ${svtValidationPreview.ok ? 'bg-[#00C88C]/20 text-[#00C88C]' : 'bg-amber-500/20 text-amber-300'}`}>
                                Sections SVT {svtSectionsProgress}/13
                            </span>
                            <span className="text-[9px] font-black uppercase text-slate-700 tracking-widest">Markdown Supporté</span>
                        </div>
                    </div>
                    <textarea value={content} onChange={(e) => setContent(e.target.value)} rows="18" placeholder="Contenu pédagogique..." className="w-full bg-[#050C0A] p-12 text-lg text-slate-300 focus:outline-none resize-none font-medium leading-relaxed" />
                </div>

                {!svtValidationPreview.ok && (
                <div className="stat-card p-8 bg-red-500/10 border border-red-500/30">
                    <div className="flex items-center space-x-3 mb-3">
                        <Info size={16} className="text-red-300" />
                        <p className="text-[10px] font-black uppercase tracking-widest text-red-300">Format SVT incomplet</p>
                    </div>
                    <p className="text-sm text-red-100 mb-3">Publication bloquée tant que toutes les sections obligatoires ne sont pas présentes dans l'ordre.</p>
                    <p className="text-xs text-red-200">Sections manquantes: {svtValidationPreview.missing.join(' | ')}</p>
                </div>
                )}

                {/* PDF URL */}
                <div className="stat-card p-10 bg-[#0D1B17]">
                    <div className="flex items-center space-x-4 mb-6">
                        <FileText size={20} className="text-[#00C88C]" />
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em]">URL PDF (optionnel)</label>
                    </div>
                    <input value={pdfUrl} onChange={(e) => setPdfUrl(e.target.value)} type="text" placeholder="https://example.com/document.pdf" className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-4 px-6 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 font-bold shadow-inner" />
                    <div className="flex items-center space-x-3 text-slate-600 px-2 mt-4">
                        <Info size={14} />
                        <p className="text-[10px] italic font-medium">Lien vers un PDF complémentaire consultable par les étudiants sur mobile</p>
                    </div>
                </div>

                {/* AI References */}
                {references.length > 0 && (
                <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
                    <div className="flex items-center space-x-4 mb-6">
                        <BookOpen size={20} className="text-purple-400" />
                        <label className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em]">Références & Ressources (IA)</label>
                        <span className="px-3 py-1 bg-purple-500/20 text-purple-400 text-[9px] font-black rounded-full uppercase">{references.length} liens</span>
                    </div>
                    <div className="space-y-4">
                        {references.map((ref, i) => (
                            <div key={i} className="flex items-center justify-between p-5 bg-[#050C0A] border border-[#1A2E28] rounded-2xl hover:border-purple-500/30 transition-all group">
                                <div className="flex items-center space-x-4 flex-1 min-w-0">
                                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${
                                        ref.type === 'guideline' ? 'bg-green-500/20' :
                                        ref.type === 'article' ? 'bg-blue-500/20' :
                                        ref.type === 'video' ? 'bg-red-500/20' : 'bg-purple-500/20'
                                    }`}>
                                        {ref.type === 'guideline' ? <BookOpen size={16} className="text-green-400" /> :
                                         ref.type === 'article' ? <FileText size={16} className="text-blue-400" /> :
                                         <Link2 size={16} className="text-purple-400" />}
                                    </div>
                                    <div className="min-w-0 flex-1">
                                        <p className="text-sm font-bold text-white truncate">{ref.title}</p>
                                        <p className="text-[10px] text-slate-500 truncate mt-1">{ref.url}</p>
                                    </div>
                                </div>
                                <a href={ref.url} target="_blank" rel="noopener noreferrer" className="ml-4 px-4 py-2 bg-purple-500/10 border border-purple-500/20 rounded-xl text-purple-400 text-[9px] font-black uppercase tracking-widest hover:bg-purple-500/20 transition-all flex-shrink-0">
                                    Ouvrir
                                </a>
                            </div>
                        ))}
                    </div>
                    <div className="flex items-center space-x-3 text-slate-600 px-2 mt-4">
                        <Info size={14} />
                        <p className="text-[10px] italic font-medium">Ces références seront accessibles aux étudiants dans l'application mobile</p>
                    </div>
                </div>
                )}

                {/* Footer Floating Action */}
                <div className="fixed bottom-12 left-1/2 -translate-x-1/2 z-50">
                    <button onClick={publishCourse} disabled={saving || (!generated && !isEditing)} className="btn-primary py-6 px-24 group shadow-[0_0_50px_rgba(0,210,140,0.4)] scale-110 disabled:opacity-40">
                        <Save size={24} className="mr-3" />
                        <span className="text-lg font-black tracking-widest uppercase">{saving ? 'Publication...' : 'Publier le quiz'}</span>
                    </button>
                </div>
            </div>
            )}
        </div>
    );
};

export default CreateCourse;
