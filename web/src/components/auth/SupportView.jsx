import React, { useState } from 'react';
import { ChevronDown, Plus, Send, ArrowLeft, CheckCircle } from 'lucide-react';

const SupportView = ({ onBack }) => {
    const [urgency, setUrgency] = useState('Standard');
    const [category, setCategory] = useState('');
    const [description, setDescription] = useState('');
    const [submitted, setSubmitted] = useState(false);
    const [error, setError] = useState('');

    const handleSubmit = (e) => {
        e.preventDefault();
        if (!category || category === 'Sélectionnez une catégorie') {
            setError('Veuillez sélectionner une catégorie.');
            return;
        }
        if (description.trim().length < 10) {
            setError('Veuillez décrire le problème (min. 10 caractères).');
            return;
        }
        setError('');
        setSubmitted(true);
    };

    return (
        <div className="min-h-screen flex flex-col items-center justify-center bg-[#050C0A] bg-gradient-to-tr from-[#050C0A] via-[#081310] to-[#0D1B17] p-8">
            <div className="flex items-center space-x-4 mb-14">
                <div className="w-10 h-10 bg-[#00C88C] rounded-xl flex items-center justify-center shadow-2xl">
                    <Plus className="text-[#050C0A]" size={24} />
                </div>
                <h1 className="text-2xl font-black text-white tracking-[0.2em] uppercase">Dica Clinic</h1>
            </div>

            <div className="w-full max-w-3xl stat-card p-16 bg-gradient-to-br from-[#11241E] to-[#081310] relative overflow-hidden animate-in zoom-in-95 duration-700">
                <div className="absolute top-0 left-0 w-full h-1 bg-[#00C88C]/30 shadow-[0_0_20px_#00C88C]"></div>

                {submitted ? (
                    <div className="text-center py-16">
                        <div className="w-20 h-20 bg-[#00C88C]/20 rounded-full flex items-center justify-center mx-auto mb-8">
                            <CheckCircle className="text-[#00C88C]" size={40} />
                        </div>
                        <h2 className="text-3xl font-black text-white mb-4 tracking-tight">Ticket envoyé !</h2>
                        <p className="text-slate-500 mb-4 text-lg">
                            Votre demande de support a été enregistrée avec le niveau <span className="text-[#00C88C] font-bold">{urgency}</span>.
                        </p>
                        <p className="text-slate-600 mb-10 text-sm">Notre équipe technique vous répondra dans les plus brefs délais.</p>
                        <button
                            onClick={onBack}
                            className="flex items-center justify-center space-x-3 text-slate-400 hover:text-white transition-colors group mx-auto py-4"
                        >
                            <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
                            <span className="text-xs font-black uppercase tracking-widest">Retour</span>
                        </button>
                    </div>
                ) : (
                    <>
                        <h2 className="text-5xl font-black text-white mb-4 text-center tracking-tight">Support IT & Technique</h2>
                        <p className="text-slate-500 text-center mb-16 text-lg font-medium">Besoin d'aide ? Envoyez un message à notre équipe technique</p>

                        <form className="space-y-12" onSubmit={handleSubmit}>
                            <div className="space-y-4">
                                <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Sujet du problème</label>
                                <div className="relative group">
                                    <select
                                        value={category}
                                        onChange={(e) => setCategory(e.target.value)}
                                        className="w-full bg-[#050C0A]/60 border border-[#1A2E28] rounded-[1.5rem] py-6 px-8 text-white appearance-none focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold text-sm shadow-inner backdrop-blur-xl"
                                    >
                                        <option>Sélectionnez une catégorie</option>
                                        <option>Problème de connexion</option>
                                        <option>Bug technique</option>
                                        <option>Accès aux données</option>
                                    </select>
                                    <ChevronDown className="absolute right-8 top-1/2 -translate-y-1/2 text-slate-700 group-focus-within:text-[#00C88C] transition-colors" size={20} />
                                </div>
                            </div>

                            <div className="space-y-4">
                                <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Description détaillée</label>
                                <textarea
                                    rows="6"
                                    value={description}
                                    onChange={(e) => setDescription(e.target.value)}
                                    placeholder="Décrivez votre problème avec le plus de précisions possible..."
                                    className="w-full bg-[#050C0A]/60 border border-[#1A2E28] rounded-[2rem] py-8 px-8 text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold text-sm shadow-inner backdrop-blur-xl resize-none"
                                ></textarea>
                            </div>

                            {error && <p className="text-red-400 text-sm font-bold text-center">{error}</p>}

                            <div className="space-y-6">
                                <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Niveau d'urgence</label>
                                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                                    {[
                                        { label: 'Standard', color: '#00C88C' },
                                        { label: 'Moyen', color: '#F59E0B' },
                                        { label: 'Urgent', color: '#EF4444' },
                                        { label: 'Critique', color: '#B91C1C' },
                                    ].map((lvl) => (
                                        <button
                                            key={lvl.label}
                                            type="button"
                                            onClick={() => setUrgency(lvl.label)}
                                            className={`py-4 px-4 rounded-full border transition-all flex items-center justify-center space-x-3 text-[10px] font-black tracking-widest ${urgency === lvl.label
                                                    ? 'bg-[#00C88C] text-[#050C0A] border-[#00C88C] shadow-[0_0_20px_rgba(0,200,140,0.5)]'
                                                    : 'bg-[#050C0A]/40 text-slate-500 border-[#1A2E28] hover:border-[#00C88C]/40'
                                                }`}
                                        >
                                            <div className={`w-2 h-2 rounded-full ${urgency === lvl.label ? 'bg-[#050C0A]' : ''}`} style={{ backgroundColor: urgency === lvl.label ? '' : lvl.color }}></div>
                                            <span>{lvl.label.toUpperCase()}</span>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <button type="submit" className="w-full btn-primary py-7 shadow-[0_0_40px_rgba(34,255,140,0.4)] relative group">
                                <div className="flex items-center space-x-4">
                                    <Send size={24} className="group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
                                    <span className="text-lg font-black tracking-[.2em] uppercase">Envoyer le ticket</span>
                                </div>
                            </button>

                            <button
                                type="button"
                                onClick={onBack}
                                className="w-full flex items-center justify-center space-x-3 text-slate-600 hover:text-white transition-colors py-4 group"
                            >
                                <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
                                <span className="text-xs font-black uppercase tracking-widest">Retour</span>
                            </button>
                        </form>
                    </>
                )}
            </div>

            <div className="mt-16 text-center opacity-20">
                <p className="text-[10px] text-slate-700 font-bold uppercase tracking-[0.4em]">
                    © 2024 DICA CLINIC MANAGEMENT — V2.4.0
                </p>
            </div>
        </div>
    );
};

export default SupportView;
