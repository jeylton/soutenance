import React, { useEffect, useState } from 'react';
import { ChevronLeft, MessageCircle } from 'lucide-react';

const Feedback = ({ onBack }) => {
  const api = import.meta.env.VITE_API_URL;
  const [sessions, setSessions] = useState([]);

  useEffect(() => {
    fetch(`${api}/api/sessions?has_feedback=true`)
      .then((res) => res.json())
      .then((data) => setSessions(data.sessions || []))
      .catch(() => setSessions([]));
  }, []);

  return (
    <div className="animate-in fade-in slide-in-from-bottom-6 duration-700 pb-24">
      <header className="flex items-center justify-between mb-12 px-12">
        <div className="flex items-center space-x-6">
          <button onClick={onBack} className="p-3 bg-[#0D1B17] border border-[#1A2E28] rounded-2xl text-slate-400 hover:text-white transition-all shadow-xl">
            <ChevronLeft size={24} />
          </button>
          <div>
            <div className="flex items-center space-x-2 text-[10px] font-black text-slate-500 uppercase tracking-widest mb-1">
              <span>Sessions</span><span>/</span><span className="text-[#00C88C]">Feedback</span>
            </div>
            <h2 className="text-3xl font-black text-white tracking-tight">Feedback Tuteur</h2>
          </div>
        </div>
      </header>
      <div className="px-12 grid grid-cols-1 lg:grid-cols-2 gap-12">
        {sessions.length === 0 ? (
          <div className="text-sm text-slate-500">Aucun feedback disponible</div>
        ) : (
          sessions.map((s) => (
            <div key={s.id} className="stat-card p-8">
              <div className="flex items-center space-x-3 mb-6">
                <MessageCircle className="text-[#00C88C]" size={20} />
                <h5 className="text-xs font-black text-white uppercase tracking-widest">Session #{s.id}</h5>
              </div>
              <div className="text-[10px] text-slate-500 uppercase font-black tracking-widest mb-2">Feedback</div>
              <div className="text-sm text-slate-300 whitespace-pre-wrap">{s.feedback || '-'}</div>
              <div className="mt-6 text-[10px] text-slate-600 uppercase font-black tracking-widest">
                Case ID: {s.case_id} • User: {s.user_id}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default Feedback;
