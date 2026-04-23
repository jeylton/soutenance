import React, { useEffect, useState } from 'react';
import { ChevronLeft, BookOpen, Microscope, Star, Brain, GraduationCap, User, Heart } from 'lucide-react';

const CaseDetail = ({ caseId, onBack }) => {
  const api = import.meta.env.VITE_API_URL;
  const [caseData, setCaseData] = useState(null);
  const [exams, setExams] = useState([]);

  useEffect(() => {
    fetch(`${api}/api/cases/${caseId}`)
      .then((res) => res.json())
      .then((data) => {
        setCaseData(data.case || null);
        setExams(data.case?.case_exams || []);
      });
  }, [caseId]);

  const setDifficulty = async (d) => {
    await fetch(`${api}/api/cases/${caseId}/difficulty`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ difficulty: d }),
    });
    setCaseData({ ...caseData, difficulty: d });
  };

  const history = caseData?.medical_history || {};

  if (!caseData) return (
    <div className="p-12">
      <button onClick={onBack} className="p-3 bg-[#0D1B17] border border-[#1A2E28] rounded-2xl text-slate-400 hover:text-white transition-all shadow-xl">
        <ChevronLeft size={24} />
      </button>
      <div className="mt-6 text-slate-500">Chargement du cas…</div>
    </div>
  );

  const InfoBadge = ({ label, value, color = '#00C88C' }) => (
    <div className="px-4 py-2 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
      <span className="text-[8px] font-black text-slate-600 uppercase tracking-widest">{label}</span>
      <p className="text-sm font-bold" style={{ color }}>{value || '-'}</p>
    </div>
  );

  const ListSection = ({ title, items, color = 'text-slate-300' }) => {
    if (!items || items.length === 0) return null;
    return (
      <div className="mt-4">
        <p className="text-[10px] text-slate-500 uppercase font-black tracking-widest mb-2">{title}</p>
        <div className="flex flex-wrap gap-2">
          {items.map((item, i) => (
            <span key={i} className={`px-3 py-1 rounded-lg bg-[#050C0A] border border-[#1A2E28] text-xs font-bold ${color}`}>{item}</span>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div className="animate-in fade-in slide-in-from-bottom-6 duration-700 pb-24">
      <header className="flex items-center justify-between mb-12 px-12">
        <div className="flex items-center space-x-6">
          <button onClick={onBack} className="p-3 bg-[#0D1B17] border border-[#1A2E28] rounded-2xl text-slate-400 hover:text-white transition-all shadow-xl">
            <ChevronLeft size={24} />
          </button>
          <div>
            <div className="flex items-center space-x-2 text-[10px] font-black text-slate-500 uppercase tracking-widest mb-1">
              <span>Cas</span><span>/</span><span className="text-[#00C88C]">Détail</span>
            </div>
            <h2 className="text-3xl font-black text-white tracking-tight">
              {caseData.patient_name || `Cas #${caseId}`}
            </h2>
          </div>
        </div>
        {caseData.avatar && (
          <img src={caseData.avatar} alt="avatar" className="w-16 h-16 rounded-2xl border-2 border-[#1A2E28] object-cover" />
        )}
      </header>

      <div className="px-12 grid grid-cols-1 lg:grid-cols-2 gap-12">
        {/* Left column */}
        <div className="space-y-8">
          {/* Patient info */}
          <div className="stat-card p-10">
            <div className="flex items-center space-x-3 mb-6">
              <User className="text-[#00C88C]" size={20} />
              <h5 className="text-xs font-black text-white uppercase tracking-widest">Patient</h5>
            </div>
            <div className="grid grid-cols-3 gap-4">
              <InfoBadge label="Nom" value={caseData.patient_name} />
              <InfoBadge label="Âge" value={history.age ? `${history.age} ans` : '-'} />
              <InfoBadge label="Genre" value={history.gender} />
            </div>
            <div className="mt-6 grid grid-cols-2 gap-4">
              <InfoBadge label="Diagnostic" value={caseData.disease_id || caseData.logic_medicale} color="#f59e0b" />
              <div className="px-4 py-2 rounded-xl bg-[#050C0A] border border-[#1A2E28]">
                <span className="text-[8px] font-black text-slate-600 uppercase tracking-widest">Difficulté</span>
                <div className="flex space-x-1 mt-1">
                  {[1,2,3,4,5].map((d) => (
                    <button key={d} onClick={() => setDifficulty(d)}><Star size={16} className={d <= (caseData.difficulty || 1) ? "fill-[#00C88C] text-[#00C88C]" : "text-slate-800"} /></button>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Consultation */}
          <div className="stat-card p-10">
            <div className="flex items-center space-x-3 mb-6">
              <BookOpen className="text-[#00C88C]" size={20} />
              <h5 className="text-xs font-black text-white uppercase tracking-widest">Motif de consultation</h5>
            </div>
            <p className="text-sm text-slate-300 leading-relaxed">{caseData.consultation_reason}</p>
            <div className="mt-6">
              <p className="text-[10px] text-slate-500 uppercase font-black tracking-widest mb-2">Symptômes initiaux</p>
              <p className="text-sm text-slate-300">{caseData.initial_symptoms || '-'}</p>
            </div>
          </div>

          {/* Historique */}
          <div className="stat-card p-10">
            <div className="flex items-center space-x-3 mb-6">
              <Heart className="text-[#00C88C]" size={20} />
              <h5 className="text-xs font-black text-white uppercase tracking-widest">Historique Médical</h5>
            </div>
            <ListSection title="Antécédents Personnels" items={history.antecedents?.perso} />
            <ListSection title="Antécédents Familiaux — Père" items={history.antecedents?.familiaux?.pere} />
            <ListSection title="Antécédents Familiaux — Mère" items={history.antecedents?.familiaux?.mere} />
            <ListSection title="Allergies" items={history.allergies} color="text-rose-400" />
            {history.habits && (
              <ListSection title="Habitudes" items={Array.isArray(history.habits) ? history.habits : [history.habits]} color="text-blue-400" />
            )}
          </div>
        </div>

        {/* Right column */}
        <div className="space-y-8">
          {/* Exams */}
          <div className="stat-card p-10">
            <div className="flex items-center space-x-3 mb-6">
              <Microscope className="text-[#00C88C]" size={20} />
              <h5 className="text-xs font-black text-white uppercase tracking-widest">Examens prédéfinis</h5>
            </div>
            {exams.length === 0 ? (
              <div className="text-sm text-slate-500">Aucun examen</div>
            ) : (
              <div className="space-y-4">
                {exams.map((e, idx) => (
                  <div key={idx} className="p-4 bg-[#050C0A] border border-[#1A2E28] rounded-xl">
                    <div className="text-xs font-black text-white uppercase tracking-widest mb-2">{e.name}</div>
                    <div className="text-sm text-slate-300">{e.result}</div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Prompts IA */}
          {(caseData.prompt_patient || caseData.prompt_tuteur) && (
            <div className="stat-card p-10">
              <div className="flex items-center space-x-3 mb-6">
                <Brain className="text-[#00C88C]" size={20} />
                <h5 className="text-xs font-black text-white uppercase tracking-widest">Prompts IA</h5>
              </div>
              {caseData.prompt_patient && (
                <div className="mb-6">
                  <p className="text-[10px] text-slate-500 uppercase font-black tracking-widest mb-2">Prompt Patient</p>
                  <pre className="text-xs text-slate-300 bg-[#050C0A] p-4 rounded-xl border border-[#1A2E28] overflow-auto whitespace-pre-wrap">{caseData.prompt_patient}</pre>
                </div>
              )}
              {caseData.prompt_tuteur && (
                <div>
                  <div className="flex items-center space-x-2 mb-2">
                    <GraduationCap className="text-[#00C88C]" size={14} />
                    <p className="text-[10px] text-slate-500 uppercase font-black tracking-widest">Prompt Tuteur</p>
                  </div>
                  <pre className="text-xs text-slate-300 bg-[#050C0A] p-4 rounded-xl border border-[#1A2E28] overflow-auto whitespace-pre-wrap">{caseData.prompt_tuteur}</pre>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default CaseDetail;
