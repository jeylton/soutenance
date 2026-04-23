import React, { useState } from 'react';
import { Mail, ChevronLeft, Plus, ArrowRight, CheckCircle } from 'lucide-react';

const ForgotPasswordView = ({ onBack }) => {
    const [email, setEmail] = useState('');
    const [sent, setSent] = useState(false);
    const [error, setError] = useState('');

    const handleSubmit = (e) => {
        e.preventDefault();
        if (!email.trim() || !email.includes('@')) {
            setError('Veuillez entrer un email valide.');
            return;
        }
        setError('');
        setSent(true);
    };

    return (
    <div className="min-h-screen grid grid-cols-1 lg:grid-cols-2 bg-[#050C0A]">
        {/* Left Side - Graphic Header based on mockup */}
        <div className="hidden lg:flex flex-col justify-center items-center p-20 bg-[#020806] relative overflow-hidden">
            {/* Geometric pattern from the new mockup */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[350px] h-[700px] border border-dashed border-[#00C88C]/30 rounded-full rotate-0"></div>

            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 flex flex-col space-y-24">
                {[...Array(5)].map((_, i) => (
                    <div key={i} className={`w-3 h-3 bg-[#00C88C] rounded-full shadow-[0_0_15px_#00C88C] ${i % 2 === 0 ? '-translate-x-24' : 'translate-x-24'}`}></div>
                ))}
            </div>

            <div className="relative z-10 text-left w-full max-w-lg mt-auto">
                <h2 className="text-6xl font-black text-white mb-6 leading-tight tracking-tighter">
                    Système de Gestion <br />Avancé
                </h2>
                <p className="text-xl text-slate-400 leading-relaxed max-w-md font-medium">
                    Sécurisez l'accès aux données de santé de vos patients avec les derniers standards de cryptage biomédical.
                </p>
            </div>
        </div>

        {/* Right Side - Form */}
        <div className="flex flex-col justify-center items-center p-10 border-l border-[#152924]">
            <div className="w-full max-w-md animate-in fade-in slide-in-from-right-8 duration-700">
                <div className="flex items-center space-x-4 mb-20">
                    <div className="w-14 h-14 bg-[#00C88C] rounded-2xl flex items-center justify-center shadow-[0_0_30px_rgba(0,200,140,0.3)]">
                        <Plus className="text-[#050C0A]" size={32} />
                    </div>
                    <h1 className="text-3xl font-black text-white tracking-widest uppercase">Dica Clinic</h1>
                </div>

                {sent ? (
                    <div className="text-center py-16">
                        <div className="w-20 h-20 bg-[#00C88C]/20 rounded-full flex items-center justify-center mx-auto mb-8">
                            <CheckCircle className="text-[#00C88C]" size={40} />
                        </div>
                        <h2 className="text-3xl font-black text-white mb-4 tracking-tight">Email envoyé !</h2>
                        <p className="text-slate-500 mb-10 text-lg">
                            Si un compte est associé à <span className="text-[#00C88C] font-bold">{email}</span>,
                            vous recevrez un lien de réinitialisation.
                        </p>
                        <button
                            onClick={onBack}
                            className="flex items-center justify-center space-x-3 text-slate-400 hover:text-white transition-colors group mx-auto py-4"
                        >
                            <ChevronLeft size={20} className="group-hover:-translate-x-1 transition-transform" />
                            <span className="text-xs font-black uppercase tracking-widest">Retour à la connexion</span>
                        </button>
                    </div>
                ) : (
                    <>
                        <h2 className="text-5xl font-black text-white mb-4 tracking-tight leading-tight">Récupération de compte</h2>
                        <p className="text-slate-500 mb-14 text-lg">Saisissez votre email professionnel pour recevoir un lien de réinitialisation.</p>

                        <form onSubmit={handleSubmit} className="space-y-10">
                            <div className="space-y-4">
                                <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Email professionnel</label>
                                <div className="relative group">
                                    <Mail className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-700 group-focus-within:text-[#00C88C] transition-colors" size={22} />
                                    <input
                                        type="email"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        placeholder="exemple@dicaclinic.com"
                                        className="w-full bg-[#0D1B17] border border-[#1A2E28] rounded-[1.5rem] py-6 pl-16 pr-8 text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold text-lg shadow-inner"
                                    />
                                </div>
                                {error && <p className="text-red-400 text-sm font-bold px-1">{error}</p>}
                            </div>

                            <button type="submit" className="w-full btn-primary group py-6 shadow-[0_0_40px_rgba(0,200,140,0.4)]">
                                <span className="tracking-[0.2em] font-black uppercase">Envoyer le lien</span>
                                <ArrowRight size={24} className="group-hover:translate-x-2 transition-transform ml-3" />
                            </button>

                            <button
                                type="button"
                                onClick={onBack}
                                className="w-full flex items-center justify-center space-x-3 text-slate-600 hover:text-white transition-colors group py-4"
                            >
                                <ChevronLeft size={20} className="group-hover:-translate-x-1 transition-transform" />
                                <span className="text-xs font-black uppercase tracking-widest">Retour à la connexion</span>
                            </button>
                        </form>
                    </>
                )}

                <div className="mt-40 text-center opacity-30">
                    <p className="text-[10px] text-slate-700 font-bold uppercase tracking-[0.4em]">
                        © 2024 DICA CLINIC MANAGEMENT — V2.4.0
                    </p>
                </div>
            </div>
        </div>
    </div>
    );
};

export default ForgotPasswordView;
