import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Sparkles, Brain, CheckCircle2, Send, Eye, Archive, RotateCcw, Trash2, Star, Info, Plus, LayoutGrid, List, ChevronLeft, X } from 'lucide-react';

const normalize = (value) =>
  String(value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

const SEASONS = 5;
const EPISODES = 10;
const DIFF_LABELS = ['Très facile', 'Facile', 'Moyen', 'Difficile', 'Expert'];
const DIFF_COLORS = ['#22c55e', '#84cc16', '#f59e0b', '#ef4444', '#a855f7'];

// ─── Grille saisons/épisodes ──────────────────────────────────────────────────
const SeasonMap = ({ quizzes, specialtyId, onGenerate, onView, onToggleArchive, onDelete }) => {
  const getQuizForSlot = (season, episode) =>
    quizzes.find(
      (q) =>
        String(q.specialty_id) === String(specialtyId) &&
        Number(q.season) === season &&
        Number(q.episode) === episode,
    );

  const totalPublished = quizzes.filter(
    (q) => String(q.specialty_id) === String(specialtyId) && (q.status || 'published') === 'published',
  ).length;

  return (
    <div className="space-y-6">
      {/* Résumé */}
      <div className="flex items-center space-x-4 p-4 bg-[#0D1B17] rounded-2xl border border-[#1A2E28]">
        <div className="w-10 h-10 rounded-xl bg-[#00C88C]/10 border border-[#00C88C]/20 flex items-center justify-center text-[#00C88C]">
          <LayoutGrid size={18} />
        </div>
        <div>
          <p className="text-white font-black">{totalPublished} / {SEASONS * EPISODES} quiz publiés</p>
          <p className="text-[10px] text-slate-500 font-bold uppercase tracking-widest">
            {SEASONS} saisons × {EPISODES} épisodes
          </p>
        </div>
      </div>

      {/* Grille par saison */}
      {Array.from({ length: SEASONS }, (_, si) => {
        const season = si + 1;
        const seasonQuizzes = quizzes.filter(
          (q) => String(q.specialty_id) === String(specialtyId) && Number(q.season) === season,
        );
        const publishedCount = seasonQuizzes.filter((q) => (q.status || 'published') === 'published').length;

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
                <span className="text-[10px] text-slate-500 font-bold">{DIFF_LABELS[si]}</span>
              </div>
              <div className="flex items-center space-x-2">
                <span
                  className="text-[10px] font-black px-2 py-1 rounded-lg"
                  style={{ color: DIFF_COLORS[si], background: DIFF_COLORS[si] + '15' }}
                >
                  {publishedCount}/{EPISODES}
                </span>
                <div className="w-24 h-1.5 bg-[#1A2E28] rounded-full overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{ width: `${(publishedCount / EPISODES) * 100}%`, backgroundColor: DIFF_COLORS[si] }}
                  />
                </div>
              </div>
            </div>

            {/* Grille épisodes */}
            <div className="grid grid-cols-5 gap-3 md:grid-cols-10">
              {Array.from({ length: EPISODES }, (_, ei) => {
                const episode = ei + 1;
                const q = getQuizForSlot(season, episode);

                if (!q) {
                  return (
                    <button
                      key={episode}
                      onClick={() => onGenerate(season, episode)}
                      className="aspect-square rounded-xl border-2 border-dashed border-[#1A2E28] flex flex-col items-center justify-center text-slate-700 hover:border-[#00C88C]/40 hover:text-[#00C88C] transition-all"
                    >
                      <Plus size={14} className="mb-1" />
                      <span className="text-[8px] font-black">E{episode}</span>
                    </button>
                  );
                }

                const isPublished = (q.status || 'published') === 'published';
                const isArchived = q.status === 'archived';

                return (
                  <div
                    key={episode}
                    className={`aspect-square rounded-xl border-2 flex flex-col items-center justify-center relative group cursor-pointer transition-all
                      ${isPublished ? 'border-[#00C88C]/40 bg-[#00C88C]/5 hover:border-[#00C88C]' : ''}
                      ${isArchived ? 'border-[#1A2E28] bg-[#050C0A] opacity-50' : ''}
                    `}
                  >
                    <span className={`text-[8px] font-black mb-0.5 ${isPublished ? 'text-[#00C88C]' : 'text-slate-500'}`}>
                      E{episode}
                    </span>
                    <span className={`text-[7px] font-bold ${isPublished ? 'text-[#00C88C]/70' : 'text-slate-600'}`}>
                      {isPublished ? '✓' : isArchived ? '🗄' : '~'}
                    </span>
                    {/* Actions au survol */}
                    <div className="absolute inset-0 rounded-xl bg-black/80 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1">
                      <button onClick={() => onView(q)} className="p-1 text-white hover:text-[#00C88C]" title="Voir">
                        <Eye size={10} />
                      </button>
                      <button
                        onClick={() => onToggleArchive(q)}
                        className="p-1 text-white hover:text-amber-400"
                        title={isArchived ? 'Restaurer' : 'Archiver'}
                      >
                        {isArchived ? <RotateCcw size={10} /> : <Archive size={10} />}
                      </button>
                      <button onClick={() => onDelete(q)} className="p-1 text-white hover:text-rose-400" title="Supprimer">
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

// ─── Composant principal ──────────────────────────────────────────────────────
const QuizManagement = () => {
  const rawApi = (import.meta.env.VITE_API_URL || 'http://localhost:5000').trim().replace(/\/+$/, '');
  const apiRoot = rawApi.toLowerCase().endsWith('/api') ? rawApi : `${rawApi}/api`;

  const [specialties, setSpecialties] = useState([]);
  const [selectedSpecialtyId, setSelectedSpecialtyId] = useState('');
  const [loadingMeta, setLoadingMeta] = useState(true);
  const [publishedQuizzes, setPublishedQuizzes] = useState([]);
  const [loadingPublished, setLoadingPublished] = useState(false);
  const [viewMode, setViewMode] = useState('map'); // 'map' | 'list'
  const [filter, setFilter] = useState('all');

  // Panneau génération
  const [generatingSlot, setGeneratingSlot] = useState(null); // { season, episode }
  const [generating, setGenerating] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [pendingQuiz, setPendingQuiz] = useState(null); // quiz généré en attente de publication

  // Panneau visualisation
  const [viewingQuiz, setViewingQuiz] = useState(null);

  const selectedSpecialty = useMemo(
    () => specialties.find((s) => String(s.id) === String(selectedSpecialtyId)) || null,
    [specialties, selectedSpecialtyId],
  );

  const scopedQuizzes = useMemo(
    () => (selectedSpecialtyId ? publishedQuizzes.filter((q) => String(q.specialty_id) === String(selectedSpecialtyId)) : []),
    [publishedQuizzes, selectedSpecialtyId],
  );

  const visibleQuizzes = useMemo(() => {
    if (filter === 'all') return scopedQuizzes;
    return scopedQuizzes.filter((q) => (q.status || 'published') === filter);
  }, [scopedQuizzes, filter]);

  const fetchJson = async (url, options) => {
    const res = await fetch(url, options);
    const contentType = res.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error || `Erreur API (${res.status})`);
      return data;
    }
    const raw = await res.text();
    throw new Error(`Réponse non JSON (${res.status}). Vérifiez VITE_API_URL. Détail: ${String(raw).slice(0, 120)}`);
  };

  useEffect(() => {
    fetchJson(`${apiRoot}/specialties`)
      .then((d) => setSpecialties(d.specialties || []))
      .catch(() => setSpecialties([]))
      .finally(() => setLoadingMeta(false));
  }, [apiRoot]);

  const loadPublishedQuizzes = async () => {
    setLoadingPublished(true);
    try {
      const params = new URLSearchParams({ status: 'all' });
      if (selectedSpecialtyId) params.set('specialty_id', String(selectedSpecialtyId));
      const data = await fetchJson(`${apiRoot}/llm/published-quizzes?${params}`);
      setPublishedQuizzes(Array.isArray(data?.quizzes) ? data.quizzes : []);
    } catch (_) {
      setPublishedQuizzes([]);
    } finally {
      setLoadingPublished(false);
    }
  };

  useEffect(() => {
    loadPublishedQuizzes();
  }, [apiRoot, selectedSpecialtyId]);

  // ── Génération ────────────────────────────────────────────────────────────
  const handleGenerate = async (season, episode) => {
    setGeneratingSlot({ season, episode });
    setPendingQuiz(null);
    setGenerating(true);
    try {
      // Récupérer le cas clinique correspondant à ce slot
      const casesData = await fetchJson(`${apiRoot}/llm/quiz-cases/${selectedSpecialtyId}?season=${season}`);
      const cases = Array.isArray(casesData?.cases) ? casesData.cases : [];
      const caseRow = cases.find((c) => Number(c.episode) === episode);

      if (!caseRow) {
        alert(`Aucun cas clinique publié trouvé pour la Saison ${season} – Épisode ${episode}. Publiez d'abord le cas clinique correspondant.`);
        return;
      }

      const data = await fetchJson(`${apiRoot}/llm/generate-quiz`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          specialty_id: Number(selectedSpecialtyId),
          question_count: 30,
          case_id: Number(caseRow.id),
          difficulty: season,
        }),
      });

      setPendingQuiz({
        ...(data.quiz || {}),
        specialty_id: Number(selectedSpecialtyId),
        season,
        episode,
        case_id: Number(caseRow.id),
        difficulty: season,
      });
    } catch (e) {
      alert(e.message || 'Erreur de génération');
      setGeneratingSlot(null);
    } finally {
      setGenerating(false);
    }
  };

  const handlePublish = async () => {
    if (!pendingQuiz) return;
    const { season, episode, case_id, difficulty } = pendingQuiz;
    const specialtyId = Number(selectedSpecialtyId);
    const quizKey = `sp-${specialtyId}-s${season}-e${episode}`;

    setPublishing(true);
    try {
      await fetchJson(`${apiRoot}/llm/publish-quiz`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: 'published',
          season,
          episode,
          level: 1,
          difficulty,
          case_id,
          quiz: { ...pendingQuiz, quiz_key: quizKey },
        }),
      });
      await loadPublishedQuizzes();
      setPendingQuiz(null);
      setGeneratingSlot(null);
      alert('Quiz publié avec succès !');
    } catch (e) {
      alert(e.message || 'Erreur publication');
    } finally {
      setPublishing(false);
    }
  };

  // ── Archive / Supprimer ───────────────────────────────────────────────────
  const handleToggleArchive = async (row) => {
    const next = row.status === 'archived' ? 'published' : 'archived';
    try {
      const updated = await fetchJson(`${apiRoot}/llm/published-quizzes/${row.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: next }),
      });
      setPublishedQuizzes((prev) => prev.map((q) => (q.id === row.id ? updated.quiz : q)));
    } catch (e) {
      alert(e.message || 'Erreur archivage');
    }
  };

  const handleDelete = async (row) => {
    if (!window.confirm(`Supprimer définitivement "${row.title || 'Quiz'}" ?`)) return;
    try {
      await fetchJson(`${apiRoot}/llm/published-quizzes/${row.id}`, { method: 'DELETE' });
      setPublishedQuizzes((prev) => prev.filter((q) => q.id !== row.id));
      if (viewingQuiz?.id === row.id) setViewingQuiz(null);
    } catch (e) {
      alert(e.message || 'Erreur suppression');
    }
  };

  // ── Rendu ─────────────────────────────────────────────────────────────────
  return (
    <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-8">

      {/* ── Sélection spécialité ── */}
      {!selectedSpecialtyId ? (
        <div className="space-y-6">
          <div className="stat-card p-8 bg-[#0D1B17] border border-[#1A2E28]">
            <div className="flex items-center gap-3 mb-2">
              <Brain className="text-[#00C88C]" size={22} />
              <h3 className="text-2xl font-black text-white tracking-tight">Gestion des Quiz</h3>
            </div>
            <p className="text-sm text-slate-400">Sélectionnez une spécialité pour gérer ses quiz par saison et épisode.</p>
          </div>

          {loadingMeta ? (
            <div className="stat-card p-8 text-slate-400">Chargement des spécialités...</div>
          ) : specialties.length === 0 ? (
            <div className="stat-card p-8 text-slate-400">Aucune spécialité trouvée.</div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
              {specialties.map((sp) => (
                <button
                  key={sp.id}
                  onClick={() => setSelectedSpecialtyId(String(sp.id))}
                  className="stat-card p-8 text-left hover:border-[#00C88C]/40 transition-all"
                >
                  <p className="text-[10px] text-[#00C88C] font-black uppercase tracking-[0.2em] mb-2">Spécialité</p>
                  <p className="text-2xl font-black text-white">{sp.name}</p>
                </button>
              ))}
            </div>
          )}
        </div>

      ) : (
        <div className="space-y-6">
          {/* Header */}
          <div className="stat-card p-6 bg-[#0D1B17] border border-[#1A2E28]">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <button
                  onClick={() => { setSelectedSpecialtyId(''); setPendingQuiz(null); setGeneratingSlot(null); setViewingQuiz(null); }}
                  className="px-4 py-2 rounded-lg text-[10px] font-black uppercase tracking-widest bg-[#050C0A] text-slate-400 border border-[#1A2E28] hover:text-white hover:bg-[#11241E] transition-all"
                >
                  ← Spécialités
                </button>
                <Brain className="text-[#00C88C]" size={22} />
                <div>
                  <h3 className="text-2xl font-black text-white tracking-tight">Quiz Cliniques</h3>
                  <p className="text-sm text-slate-400">{selectedSpecialty?.name || ''}</p>
                </div>
              </div>
              {/* Toggles vue */}
              <div className="flex items-center gap-2">
                {[{ label: 'Tous', value: 'all' }, { label: 'Publiés', value: 'published' }, { label: 'Archivés', value: 'archived' }].map((t) => (
                  <button
                    key={t.value}
                    onClick={() => setFilter(t.value)}
                    className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest ${filter === t.value ? 'bg-[#00C88C] text-[#03241A]' : 'bg-[#050C0A] text-slate-400 border border-[#1A2E28]'}`}
                  >
                    {t.label}
                  </button>
                ))}
                <div className="w-px h-5 bg-[#1A2E28] mx-1" />
                <button
                  onClick={() => setViewMode('map')}
                  className={`p-2 rounded-lg border ${viewMode === 'map' ? 'bg-[#00C88C]/10 border-[#00C88C]/30 text-[#00C88C]' : 'border-[#1A2E28] text-slate-500'}`}
                  title="Vue carte"
                >
                  <LayoutGrid size={16} />
                </button>
                <button
                  onClick={() => setViewMode('list')}
                  className={`p-2 rounded-lg border ${viewMode === 'list' ? 'bg-[#00C88C]/10 border-[#00C88C]/30 text-[#00C88C]' : 'border-[#1A2E28] text-slate-500'}`}
                  title="Vue liste"
                >
                  <List size={16} />
                </button>
              </div>
            </div>
          </div>

          {/* ── Panneau génération (slot sélectionné) ── */}
          {generatingSlot && (
            <div className="stat-card p-6 bg-[#0D1B17] border border-[#00C88C]/30">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <Sparkles className="text-[#00C88C]" size={18} />
                  <div>
                    <p className="text-white font-black">
                      Saison {generatingSlot.season} — Épisode {generatingSlot.episode}
                    </p>
                    <p className="text-[11px] text-slate-400">{DIFF_LABELS[generatingSlot.season - 1]}</p>
                  </div>
                </div>
                <button
                  onClick={() => { setGeneratingSlot(null); setPendingQuiz(null); }}
                  className="p-2 rounded-lg border border-[#1A2E28] text-slate-500 hover:text-white"
                >
                  <X size={14} />
                </button>
              </div>

              {generating ? (
                <div className="flex items-center gap-3 text-slate-400 py-4">
                  <div className="w-4 h-4 border-2 border-[#00C88C] border-t-transparent rounded-full animate-spin" />
                  <span className="text-sm">Génération du quiz en cours...</span>
                </div>
              ) : !pendingQuiz ? (
                <button
                  onClick={() => handleGenerate(generatingSlot.season, generatingSlot.episode)}
                  className="btn-primary py-3 px-6 inline-flex items-center gap-2"
                >
                  <Sparkles size={16} />
                  <span className="font-black uppercase tracking-widest text-sm">Générer le Quiz</span>
                </button>
              ) : (
                <div className="space-y-4">
                  {/* Aperçu quiz */}
                  <div>
                    <p className="text-white font-black text-lg">{pendingQuiz.title || 'Quiz'}</p>
                    <p className="text-[#00C88C] text-sm font-bold">Maladie : {pendingQuiz.disease || 'Non précisée'}</p>
                    <p className="text-slate-400 text-xs mt-1">{(pendingQuiz.questions || []).length} questions générées</p>
                  </div>

                  {/* Questions (scroll) */}
                  <div className="space-y-3 max-h-72 overflow-y-auto pr-1">
                    {(pendingQuiz.questions || []).map((q, idx) => (
                      <div key={q.id || idx} className="p-4 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                        <p className="text-[10px] uppercase tracking-widest text-slate-500 font-black mb-1">Q{idx + 1}</p>
                        <p className="text-white font-bold text-sm mb-2">{q.question}</p>
                        <div className="grid grid-cols-2 gap-1.5">
                          {['A', 'B', 'C', 'D'].map((opt) => (
                            <div
                              key={opt}
                              className={`p-2 rounded-lg border text-xs ${normalize(q.answer) === normalize(opt)
                                ? 'border-green-400/60 bg-green-500/10 text-green-200'
                                : 'border-[#1A2E28] text-slate-400'}`}
                            >
                              <span className="font-black text-slate-500 mr-1">{opt}</span>
                              {q.options?.[opt] || ''}
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="flex items-center gap-3 pt-2">
                    <button
                      onClick={handlePublish}
                      disabled={publishing}
                      className="btn-primary py-2.5 px-5 inline-flex items-center gap-2 disabled:opacity-50"
                    >
                      <Send size={14} />
                      {publishing ? 'Publication...' : 'Publier le quiz'}
                    </button>
                    <button
                      onClick={() => handleGenerate(generatingSlot.season, generatingSlot.episode)}
                      className="px-4 py-2.5 rounded-lg text-[10px] font-black uppercase tracking-widest bg-[#050C0A] text-slate-400 border border-[#1A2E28] hover:text-white transition-all"
                    >
                      Regénérer
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* ── Panneau visualisation quiz existant ── */}
          {viewingQuiz && !generatingSlot && (
            <div className="stat-card p-6 bg-[#0D1B17] border border-[#1A2E28]">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <p className="text-white font-black text-lg">{viewingQuiz.title || 'Quiz'}</p>
                  <p className="text-[#00C88C] text-sm font-bold">Maladie : {viewingQuiz.disease || 'Non précisée'}</p>
                  <p className="text-slate-400 text-xs mt-0.5">
                    Saison {viewingQuiz.season} · Épisode {viewingQuiz.episode} · {(viewingQuiz.questions || []).length} questions
                  </p>
                </div>
                <button
                  onClick={() => setViewingQuiz(null)}
                  className="p-2 rounded-lg border border-[#1A2E28] text-slate-500 hover:text-white"
                >
                  <X size={14} />
                </button>
              </div>
              <div className="space-y-3 max-h-72 overflow-y-auto pr-1">
                {(viewingQuiz.questions || []).map((q, idx) => (
                  <div key={q.id || idx} className="p-4 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                    <p className="text-[10px] uppercase tracking-widest text-slate-500 font-black mb-1">Q{idx + 1}</p>
                    <p className="text-white font-bold text-sm mb-2">{q.question}</p>
                    <div className="grid grid-cols-2 gap-1.5">
                      {['A', 'B', 'C', 'D'].map((opt) => (
                        <div
                          key={opt}
                          className={`p-2 rounded-lg border text-xs ${normalize(q.answer) === normalize(opt)
                            ? 'border-green-400/60 bg-green-500/10 text-green-200'
                            : 'border-[#1A2E28] text-slate-400'}`}
                        >
                          <span className="font-black text-slate-500 mr-1">{opt}</span>
                          {q.options?.[opt] || ''}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ── Vue carte / liste ── */}
          {loadingPublished ? (
            <div className="stat-card p-8 text-slate-400">Chargement des quiz...</div>
          ) : viewMode === 'map' ? (
            <SeasonMap
              quizzes={visibleQuizzes}
              specialtyId={selectedSpecialtyId}
              onGenerate={(season, episode) => { setViewingQuiz(null); setGeneratingSlot({ season, episode }); setPendingQuiz(null); }}
              onView={(q) => { setGeneratingSlot(null); setViewingQuiz(q); }}
              onToggleArchive={handleToggleArchive}
              onDelete={handleDelete}
            />
          ) : (
            /* Vue liste */
            <div className="space-y-3">
              {visibleQuizzes.length === 0 ? (
                <div className="stat-card p-8 text-slate-400">Aucun quiz dans cette vue.</div>
              ) : (
                [...visibleQuizzes]
                  .sort((a, b) => {
                    if (Number(a.season) !== Number(b.season)) return Number(a.season) - Number(b.season);
                    return Number(a.episode) - Number(b.episode);
                  })
                  .map((row) => {
                    const isArchived = row.status === 'archived';
                    return (
                      <div key={row.id} className="stat-card p-4">
                        <div className="flex flex-wrap items-start justify-between gap-3">
                          <div className="min-w-0 flex-1">
                            <p className="text-white font-black truncate">{row.title || 'Quiz'}</p>
                            <p className="text-[#00C88C] text-sm font-bold truncate">Maladie : {row.disease || 'Non précisée'}</p>
                            <p className="text-slate-400 text-xs mt-0.5">
                              {(row.questions || []).length} questions · S{row.season}E{row.episode} · {row.status || 'published'}
                            </p>
                          </div>
                          <div className="flex items-center gap-2">
                            <button onClick={() => { setGeneratingSlot(null); setViewingQuiz(row); }} className="p-2 bg-[#11241E] text-slate-300 hover:text-white rounded-lg border border-[#1A2E28]" title="Voir">
                              <Eye size={14} />
                            </button>
                            <button onClick={() => handleToggleArchive(row)} className="p-2 bg-[#11241E] text-slate-300 hover:text-amber-400 rounded-lg border border-[#1A2E28]" title={isArchived ? 'Restaurer' : 'Archiver'}>
                              {isArchived ? <RotateCcw size={14} /> : <Archive size={14} />}
                            </button>
                            <button onClick={() => handleDelete(row)} className="p-2 bg-[#11241E] text-slate-300 hover:text-rose-400 rounded-lg border border-[#1A2E28]" title="Supprimer">
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </div>
                      </div>
                    );
                  })
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default QuizManagement;
