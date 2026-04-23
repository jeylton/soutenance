import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Sparkles, Brain, CheckCircle2, Send, Eye, Archive, RotateCcw, Trash2 } from 'lucide-react';

const normalize = (value) =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();

const QuizManagement = () => {
  const rawApi = (import.meta.env.VITE_API_URL || 'http://localhost:5000').trim().replace(/\/+$/, '');
  const apiRoot = rawApi.toLowerCase().endsWith('/api') ? rawApi : `${rawApi}/api`;
  const [specialties, setSpecialties] = useState([]);
  const [selectedSpecialtyId, setSelectedSpecialtyId] = useState('');
  const [diseases, setDiseases] = useState([]);
  const [selectedDisease, setSelectedDisease] = useState('');
  const [questionCount, setQuestionCount] = useState(30);

  const [loadingMeta, setLoadingMeta] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [quiz, setQuiz] = useState(null);
  const [publishedMsg, setPublishedMsg] = useState('');
  const [publishedQuizzes, setPublishedQuizzes] = useState([]);
  const [loadingPublished, setLoadingPublished] = useState(false);
  const [filter, setFilter] = useState('all');
  const publishedListRef = useRef(null);

  const fetchJson = async (url, options) => {
    const res = await fetch(url, options);
    const contentType = res.headers.get('content-type') || '';
    const method = String(options?.method || 'GET').toUpperCase();

    if (contentType.includes('application/json')) {
      const data = await res.json();
      if (!res.ok) throw new Error(data?.error || `Erreur API (${res.status})`);
      return data;
    }

    const raw = await res.text();
    const preview = String(raw || '').replace(/\s+/g, ' ').slice(0, 120);
    throw new Error(
      `Réponse non JSON reçue (${res.status}) sur ${method} ${url}. Vérifiez VITE_API_URL. Détail: ${preview}`,
    );
  };

  useEffect(() => {
    fetchJson(`${apiRoot}/specialties`)
      .then((d) => setSpecialties(d.specialties || []))
      .catch(() => setSpecialties([]))
      .finally(() => setLoadingMeta(false));
  }, [apiRoot]);

  useEffect(() => {
    if (!selectedSpecialtyId) {
      setDiseases([]);
      setSelectedDisease('');
      return;
    }

    fetchJson(`${apiRoot}/llm/quiz-diseases/${selectedSpecialtyId}`)
      .then((d) => setDiseases(d.diseases || []))
      .catch(() => setDiseases([]));
  }, [apiRoot, selectedSpecialtyId]);

  const loadPublishedQuizzes = async (targetFilter = filter) => {
    setLoadingPublished(true);
    try {
      const params = new URLSearchParams();
      params.set('status', targetFilter || 'all');
      const data = await fetchJson(`${apiRoot}/llm/published-quizzes?${params.toString()}`);
      setPublishedQuizzes(Array.isArray(data?.quizzes) ? data.quizzes : []);
    } catch (_) {
      setPublishedQuizzes([]);
    } finally {
      setLoadingPublished(false);
    }
  };

  useEffect(() => {
    loadPublishedQuizzes(filter);
  }, [apiRoot, filter]);

  const questions = useMemo(() => (Array.isArray(quiz?.questions) ? quiz.questions : []), [quiz]);

  const generateQuiz = async () => {
    if (!selectedSpecialtyId) {
      alert('Choisissez une spécialité.');
      return;
    }

    setGenerating(true);
    try {
      const data = await fetchJson(`${apiRoot}/llm/generate-quiz`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          specialty_id: Number(selectedSpecialtyId),
          question_count: Math.max(10, Math.min(40, Number(questionCount) || 30)),
          disease: selectedDisease || undefined,
        }),
      });
      const generatedQuiz = data.quiz || null;
      setQuiz(generatedQuiz);
      setPublishedMsg('');

      // Save generated quiz as draft so it appears immediately in management list.
      if (generatedQuiz && Array.isArray(generatedQuiz.questions) && generatedQuiz.questions.length > 0) {
        try {
          const draftQuizKey = `${generatedQuiz.quiz_key || 'quiz'}-draft-${Date.now()}`;
          const draftData = await fetchJson(`${apiRoot}/llm/publish-quiz`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              status: 'draft',
              quiz: {
                ...generatedQuiz,
                quiz_key: draftQuizKey,
                specialty_id: Number(selectedSpecialtyId) || generatedQuiz.specialty_id,
              },
            }),
          });
          if (filter === 'all' || filter === 'draft') {
            setPublishedQuizzes((prev) => {
              const idx = prev.findIndex((q) => q.id === draftData.quiz.id);
              if (idx >= 0) {
                const next = [...prev];
                next[idx] = draftData.quiz;
                return next;
              }
              return [draftData.quiz, ...prev];
            });
          }
        } catch (_) {
          // Keep generated preview available even if draft auto-save fails.
        }
      }
    } catch (e) {
      alert(e.message || 'Erreur de génération');
    } finally {
      setGenerating(false);
    }
  };

  const publishQuiz = async () => {
    if (!quiz || questions.length === 0) {
      alert('Aucun quiz à publier.');
      return;
    }
    setPublishing(true);
    try {
      const data = await fetchJson(`${apiRoot}/llm/publish-quiz`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: 'published',
          quiz: {
            ...quiz,
            specialty_id: Number(selectedSpecialtyId) || quiz.specialty_id,
          },
        }),
      });
      setPublishedMsg(`Quiz publié (${data?.quiz?.id || 'ok'}) et disponible côté mobile.`);
      setPublishedQuizzes((prev) => [data.quiz, ...prev]);
      setQuiz(null);
      setTimeout(() => {
        publishedListRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 80);
      alert('Quiz publié avec succès !');
    } catch (e) {
      alert(e.message || 'Erreur publication');
    } finally {
      setPublishing(false);
    }
  };

  const patchPublishedQuiz = async (id, payload) => {
    const data = await fetchJson(`${apiRoot}/llm/published-quizzes/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    return data.quiz;
  };

  const toggleArchive = async (row) => {
    const next = row.status === 'archived' ? 'published' : 'archived';
    try {
      const updated = await patchPublishedQuiz(row.id, { status: next });
      setPublishedQuizzes((prev) => prev.map((q) => (q.id === row.id ? updated : q)));
      alert(next === 'archived' ? 'Quiz archivé.' : 'Quiz restauré.');
    } catch (e) {
      alert(e.message || 'Erreur archivage');
    }
  };

  const viewPublished = (row) => {
    setQuiz(row);
    setPublishedMsg('');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const deletePublishedQuiz = async (row) => {
    const ok = window.confirm(`Supprimer définitivement le quiz "${row?.title || 'Quiz'}" ?`);
    if (!ok) return;
    try {
      await fetchJson(`${apiRoot}/llm/published-quizzes/${row.id}`, {
        method: 'DELETE',
      });
      setPublishedQuizzes((prev) => prev.filter((q) => q.id !== row.id));
      if (quiz?.id === row.id) {
        setQuiz(null);
      }
      alert('Quiz supprimé avec succès.');
    } catch (e) {
      alert(e.message || 'Erreur suppression');
    }
  };

  return (
    <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-8">
      <div ref={publishedListRef} className="stat-card p-8 bg-[#0D1B17] border border-[#1A2E28]">
        <div className="flex items-center gap-3 mb-6">
          <Brain className="text-[#00C88C]" size={22} />
          <h3 className="text-2xl font-black text-white tracking-tight">Générateur de Quiz Clinique</h3>
        </div>

        {loadingMeta ? (
          <p className="text-slate-400">Chargement des spécialités...</p>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-4 items-end">
            <div>
              <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] mb-2">Spécialité</label>
              <select
                value={selectedSpecialtyId}
                onChange={(e) => setSelectedSpecialtyId(e.target.value)}
                className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-xl py-3 px-4 text-white"
              >
                <option value="">Choisir une spécialité</option>
                {specialties.map((sp) => (
                  <option key={sp.id} value={sp.id}>{sp.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] mb-2">Maladie (optionnel)</label>
              <select
                value={selectedDisease}
                onChange={(e) => setSelectedDisease(e.target.value)}
                className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-xl py-3 px-4 text-white"
                disabled={!selectedSpecialtyId}
              >
                <option value="">Automatique (maladie de la spécialité)</option>
                {diseases.map((d) => (
                  <option key={d} value={d}>{d}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] mb-2">Nombre de questions</label>
              <input
                type="number"
                min={10}
                max={40}
                value={questionCount}
                onChange={(e) => setQuestionCount(e.target.value)}
                className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-xl py-3 px-4 text-white"
              />
            </div>

            <button
              onClick={generateQuiz}
              disabled={generating || !selectedSpecialtyId}
              className="btn-primary py-3 px-6 disabled:opacity-50"
            >
              <span className="inline-flex items-center gap-2 font-black uppercase tracking-widest text-[10px]">
                <Sparkles size={16} />
                {generating ? 'Génération...' : 'Générer Quiz'}
              </span>
            </button>
          </div>
        )}
      </div>

      {quiz && (
        <div className="stat-card p-8 bg-[#0D1B17] border border-[#1A2E28]">
          <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
            <div>
              <h4 className="text-xl font-black text-white">{quiz.title || 'Quiz'}</h4>
              <p className="text-sm text-[#00C88C] font-bold">Maladie: {quiz.disease || 'Non précisée'}</p>
            </div>
            <div className="text-right">
              <p className="text-[10px] uppercase tracking-widest text-slate-500 font-black">Questions</p>
              <p className="text-sm font-black text-white">{questions.length}</p>
            </div>
          </div>

          <div className="space-y-3 max-h-[520px] overflow-y-auto pr-1">
            {questions.map((q, idx) => (
              <div key={q.id || idx} className="p-4 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                <p className="text-[10px] uppercase tracking-widest text-slate-500 font-black mb-2">Question {idx + 1}</p>
                <p className="text-white font-bold mb-3">{q.question}</p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                  {['A', 'B', 'C', 'D'].map((opt) => (
                    <div
                      key={opt}
                      className={`p-3 rounded-lg border ${normalize(q.answer) === normalize(opt)
                        ? 'border-green-400/60 bg-green-500/10 text-green-200'
                        : 'border-[#1A2E28] bg-[#0D1B17] text-slate-300'
                        }`}
                    >
                      <span className="text-[10px] uppercase tracking-widest font-black text-slate-500 mr-2">{opt}</span>
                      {q.options?.[opt] || ''}
                    </div>
                  ))}
                </div>
                <p className="text-xs text-slate-400 mt-3">Explication: {q.explanation || 'N/A'}</p>
              </div>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 mt-6">
            <button onClick={publishQuiz} disabled={publishing} className="btn-primary py-2.5 px-5 disabled:opacity-50 inline-flex items-center gap-2">
              <Send size={14} />
              {publishing ? 'Publication...' : 'Publier le quiz'}
            </button>
            {publishedMsg && (
              <div className="inline-flex items-center gap-2 text-[#00C88C] text-sm font-bold">
                <CheckCircle2 size={16} />
                {publishedMsg}
              </div>
            )}
          </div>
        </div>
      )}

      <div className="stat-card p-8 bg-[#0D1B17] border border-[#1A2E28]">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-5">
          <h4 className="text-xl font-black text-white">Quiz publiés</h4>
          <div className="flex items-center gap-2">
            {[{ label: 'Tous', value: 'all' }, { label: 'Publiés', value: 'published' }, { label: 'Archivés', value: 'archived' }].map((t) => (
              <button
                key={t.value}
                onClick={() => setFilter(t.value)}
                className={`px-4 py-2 rounded-lg text-[10px] font-black uppercase tracking-widest ${filter === t.value ? 'bg-[#00C88C] text-[#03241A]' : 'bg-[#050C0A] text-slate-400 border border-[#1A2E28]'}`}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {loadingPublished ? (
          <p className="text-slate-400">Chargement des quiz publiés...</p>
        ) : publishedQuizzes.length === 0 ? (
          <p className="text-slate-400">Aucun quiz dans cette vue.</p>
        ) : (
          <div className="space-y-3">
            {publishedQuizzes.map((row) => {
              const isArchived = row.status === 'archived';
              return (
                <div key={row.id} className="p-4 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <>
                        <p className="text-white font-black truncate">{row.title || 'Quiz'}</p>
                        <p className="text-[#00C88C] text-sm font-bold truncate">Maladie: {row.disease || 'Non précisée'}</p>
                        <p className="text-slate-400 text-xs">{Array.isArray(row.questions) ? row.questions.length : 0} questions · {row.status || 'published'}</p>
                      </>
                    </div>

                    <div className="flex items-center gap-2">
                      <>
                        <button onClick={() => viewPublished(row)} className="p-2.5 bg-[#11241E] text-slate-300 hover:text-white rounded-lg border border-[#1A2E28]" title="Visualiser">
                          <Eye size={14} />
                        </button>
                        <button onClick={() => toggleArchive(row)} className="p-2.5 bg-[#11241E] text-slate-300 hover:text-amber-400 rounded-lg border border-[#1A2E28]" title={isArchived ? 'Restaurer' : 'Archiver'}>
                          {isArchived ? <RotateCcw size={14} /> : <Archive size={14} />}
                        </button>
                        <button onClick={() => deletePublishedQuiz(row)} className="p-2.5 bg-[#11241E] text-slate-300 hover:text-rose-400 rounded-lg border border-[#1A2E28]" title="Supprimer">
                          <Trash2 size={14} />
                        </button>
                      </>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default QuizManagement;
