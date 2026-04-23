import React, { useEffect, useState } from 'react';
import { Search, Plus, FileText, Eye, Edit2, Trash2, Clock } from 'lucide-react';

const CourseItem = ({ course, specialtyName, onDelete, onEdit, onToggleStatus }) => {
    const statusLabel = course.status === 'published' ? 'Publié' : 'Brouillon';
    const statusColor = course.status === 'published' ? 'text-[#00C88C] bg-[#00C88C]/10' : 'text-amber-500 bg-amber-500/10';

    return (
        <div className="stat-card p-6 flex items-center group hover:bg-[#11241E]/40 transition-all border-[#1A2E28] hover:border-[#00C88C]/30">
            <div className="w-16 h-16 bg-[#11241E] rounded-2xl flex flex-col items-center justify-center border border-[#1A2E28] mr-6 group-hover:scale-110 transition-transform shadow-2xl">
                <FileText className="text-[#00C88C]" size={24} />
                <span className="text-[8px] font-black text-slate-500 mt-1 uppercase">{course.pdf_url ? 'PDF' : 'TXT'}</span>
            </div>

            <div className="flex-1 min-w-0 mr-8">
                <div className="flex items-center space-x-3 mb-1.5">
                    <h4 className="text-lg font-black text-white group-hover:text-[#00C88C] transition-colors truncate tracking-tight">{course.title}</h4>
                    <span className={`text-[9px] font-black uppercase px-3 py-1 rounded-lg tracking-widest ${statusColor}`}>{statusLabel}</span>
                </div>
                <div className="flex items-center space-x-6">
                    <div className="flex items-center space-x-2 text-slate-500">
                        <Clock size={14} className="opacity-50" />
                        <span className="text-[10px] font-bold">{new Date(course.created_at).toLocaleDateString('fr-FR')}</span>
                    </div>
                    <span className="text-[9px] text-[#2A433C] font-black uppercase tracking-widest">ID #{course.id}</span>
                    {course.case_id && <span className="text-[9px] text-slate-600 font-bold">Lié au cas #{course.case_id}</span>}
                    {specialtyName && <span className="text-[9px] font-black uppercase px-2.5 py-0.5 rounded-lg bg-[#00C88C]/10 text-[#00C88C] tracking-widest">{specialtyName}</span>}
                </div>
            </div>

            <div className="flex items-center space-x-2">
                <button onClick={() => onToggleStatus(course)} className="p-3 bg-[#050C0A] hover:bg-[#11241E] rounded-xl text-slate-500 hover:text-[#00C88C] border border-[#1A2E28] transition-all" title={course.status === 'published' ? 'Passer en brouillon' : 'Publier'}>
                    <Eye size={18} />
                </button>
                <button onClick={() => onEdit(course)} className="p-3 bg-[#050C0A] hover:bg-[#11241E] rounded-xl text-slate-500 hover:text-white border border-[#1A2E28] transition-all" title="Modifier">
                    <Edit2 size={18} />
                </button>
                <button onClick={() => onDelete(course)} className="p-3 bg-[#050C0A] hover:bg-[#11241E] rounded-xl text-slate-500 hover:text-rose-500 border border-[#1A2E28] transition-all" title="Supprimer">
                    <Trash2 size={18} />
                </button>
            </div>
        </div>
    );
};

const CourseManagement = ({ onCreateNew, onEditCourse }) => {
    const api = import.meta.env.VITE_API_URL;
    const [courses, setCourses] = useState([]);
    const [specialties, setSpecialties] = useState([]);
    const [search, setSearch] = useState('');
    const [filter, setFilter] = useState('all');

    const loadCourses = () => {
        fetch(`${api}/api/courses`)
            .then((res) => res.json())
            .then((data) => setCourses(data.courses || []))
            .catch(() => setCourses([]));
    };

    useEffect(() => {
        loadCourses();
        fetch(`${api}/api/specialties`)
            .then(r => r.json())
            .then(d => setSpecialties(d.specialties || []))
            .catch(() => {});
    }, []);

    const handleDelete = async (course) => {
        if (!confirm(`Supprimer le quiz "${course.title}" ?`)) return;
        try {
            await fetch(`${api}/api/courses/${course.id}`, { method: 'DELETE' });
            loadCourses();
        } catch (e) {
            alert('Erreur: ' + e.message);
        }
    };

    const handleToggleStatus = async (course) => {
        const newStatus = course.status === 'published' ? 'draft' : 'published';
        try {
            await fetch(`${api}/api/courses/${course.id}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ status: newStatus }),
            });
            loadCourses();
        } catch (e) {
            alert('Erreur: ' + e.message);
        }
    };

    const filtered = courses.filter((c) => {
        const matchSearch = !search || c.title.toLowerCase().includes(search.toLowerCase());
        const matchFilter = filter === 'all' || c.status === filter;
        return matchSearch && matchFilter;
    });

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-10">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
                <div className="flex flex-1 max-w-2xl">
                    <div className="relative w-full group">
                        <Search className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-600 group-focus-within:text-[#00C88C] transition-colors" size={20} />
                        <input
                            type="text"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            placeholder="Rechercher un quiz..."
                            className="w-full bg-[#0D1B17] border border-[#1A2E28] rounded-[1.5rem] py-5 pl-16 pr-8 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold placeholder:text-slate-700 shadow-inner"
                        />
                    </div>
                </div>

                <div className="flex items-center space-x-3 bg-[#081310] p-1.5 rounded-2xl border border-[#1A2E28]">
                    {[{ label: 'Tous', value: 'all' }, { label: 'Publiés', value: 'published' }, { label: 'Brouillons', value: 'draft' }].map((tab) => (
                        <button
                            key={tab.value}
                            onClick={() => setFilter(tab.value)}
                            className={`px-6 py-2.5 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${filter === tab.value
                                ? 'bg-[#00C88C] text-[#050C0A] shadow-[0_0_15px_rgba(0,200,140,0.3)]'
                                : 'text-slate-500 hover:text-[#00C88C] hover:bg-[#11241E]'
                                }`}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>
            </div>

            <button
                onClick={onCreateNew}
                className="btn-primary py-4.5 px-10 group shadow-2xl"
            >
                <Plus size={22} className="mr-2 group-hover:rotate-90 transition-transform duration-300" />
                <span className="tracking-widest font-black uppercase">Nouveau Quiz</span>
            </button>

            <div className="grid grid-cols-1 gap-6">
                {filtered.length === 0 ? (
                    <div className="text-center py-16">
                        <FileText size={48} className="text-slate-800 mx-auto mb-4" />
                        <p className="text-sm text-slate-500">Aucun quiz disponible</p>
                        <p className="text-[10px] text-slate-700 mt-1">Cliquez sur &quot;Nouveau Quiz&quot; pour en créer un</p>
                    </div>
                ) : (
                    filtered.map((course) => (
                        <CourseItem
                            key={course.id}
                            course={course}
                            specialtyName={specialties.find(s => s.id === course.specialty_id)?.name || null}
                            onDelete={handleDelete}
                            onEdit={() => onEditCourse && onEditCourse(course)}
                            onToggleStatus={handleToggleStatus}
                        />
                    ))
                )}
            </div>
        </div>
    );
};

export default CourseManagement;
