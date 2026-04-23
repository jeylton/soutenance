import React, { useEffect, useMemo, useState } from 'react';
import { Mail, Lock, Eye, EyeOff, Plus, ArrowRight, AlertCircle, Loader2 } from 'lucide-react';

const LoginView = ({ onLogin, onForgotPassword, onSupport }) => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [rememberMe, setRememberMe] = useState(true);
    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const apiBase = useMemo(() => {
        const raw = (import.meta.env.VITE_API_URL || 'http://localhost:5000').trim().replace(/\/+$/, '');
        return raw;
    }, []);

    useEffect(() => {
        const savedEmail = localStorage.getItem('dica_login_email') || '';
        const savedPassword = localStorage.getItem('dica_login_password') || '';
        const envEmail = String(import.meta.env.VITE_ADMIN_EMAIL || '').trim();
        const envPassword = String(import.meta.env.VITE_ADMIN_PASSWORD || '').trim();

        if (savedEmail) setEmail(savedEmail);
        else if (envEmail) setEmail(envEmail);

        if (savedPassword) setPassword(savedPassword);
        else if (envPassword) setPassword(envPassword);

        const savedRemember = localStorage.getItem('dica_login_remember');
        if (savedRemember === 'false') setRememberMe(false);
    }, []);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!email || !password) { setError('Veuillez remplir tous les champs.'); return; }
        setError('');
        setLoading(true);
        try {
            const res = await fetch(`${apiBase}/api/auth/login-admin`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password }),
            });
            const data = await res.json();
            if (!res.ok) { setError(data.error || 'Identifiants incorrects.'); setLoading(false); return; }
            if (rememberMe) {
                localStorage.setItem('dica_login_email', email);
                localStorage.setItem('dica_login_password', password);
                localStorage.setItem('dica_login_remember', 'true');
            } else {
                localStorage.removeItem('dica_login_email');
                localStorage.removeItem('dica_login_password');
                localStorage.setItem('dica_login_remember', 'false');
            }
            onLogin(data.token, data.user);
        } catch (err) {
            setError('Impossible de contacter le serveur.');
        } finally {
            setLoading(false);
        }
    };

    return (
    <div className="min-h-screen grid grid-cols-1 lg:grid-cols-2 bg-[#050C0A]">
        {/* Left Side - Graphic Header based on mockup */}
        <div className="hidden lg:flex flex-col justify-center items-center p-20 bg-[#020806] relative overflow-hidden">
            <div className="relative z-10 text-left w-full max-w-lg">
                <h2 className="text-5xl font-extrabold text-white mb-6 leading-tight tracking-tight">
                    Système de Gestion <br />Avancé
                </h2>
                <p className="text-xl text-slate-400 leading-relaxed max-w-md">
                    Sécurisez l'accès aux données de santé de vos patients avec les derniers standards de cryptage biomédical.
                </p>
            </div>

            {/* Decorative Ovals */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[650px] border border-[#00C88C]/10 rounded-full rotate-12"></div>
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[350px] h-[600px] border border-dashed border-[#00C88C]/30 rounded-full -rotate-6"></div>

            {/* Nodes */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 flex flex-col space-y-24">
                <div className="w-3 h-3 bg-[#00C88C] rounded-full shadow-[0_0_15px_#00C88C] -translate-x-20"></div>
                <div className="w-3 h-3 bg-[#00C88C] rounded-full shadow-[0_0_15px_#00C88C] translate-x-10"></div>
                <div className="w-3 h-3 bg-[#00C88C] rounded-full shadow-[0_0_15px_#00C88C] -translate-x-10"></div>
                <div className="w-3 h-3 bg-[#00C88C] rounded-full shadow-[0_0_15px_#00C88C] translate-x-20"></div>
            </div>
        </div>

        {/* Right Side - Login Form */}
        <div className="flex flex-col justify-center items-center p-10 border-l border-[#152924]">
            <div className="w-full max-w-md animate-in fade-in slide-in-from-right-8 duration-700">
                <div className="flex items-center space-x-4 mb-20 px-2">
                    <div className="w-14 h-14 bg-[#00C88C] rounded-2xl flex items-center justify-center shadow-[0_0_30px_rgba(0,200,140,0.3)]">
                        <Plus className="text-[#050C0A]" size={32} />
                    </div>
                    <h1 className="text-3xl font-black text-white tracking-widest uppercase">Dica Clinic</h1>
                </div>

                <h2 className="text-5xl font-black text-white mb-4 tracking-tight">Connexion</h2>
                <p className="text-slate-500 mb-14 text-lg">Veuillez entrer vos identifiants pour accéder au tableau de bord.</p>

                <form className="space-y-8" onSubmit={handleSubmit}>
                    {error && (
                        <div className="flex items-center space-x-3 bg-red-500/10 border border-red-500/20 rounded-2xl p-4">
                            <AlertCircle size={18} className="text-red-400 shrink-0" />
                            <span className="text-sm text-red-400 font-bold">{error}</span>
                        </div>
                    )}

                    <div className="space-y-3">
                        <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">Email professionnel</label>
                        <div className="relative group">
                            <Mail className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-700 group-focus-within:text-[#00C88C] transition-colors" size={20} />
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                placeholder="exemple@dicaclinic.com"
                                className="w-full bg-[#0D1B17] border border-[#1A2E28] rounded-[1.25rem] py-5 pl-14 pr-4 text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold text-sm"
                            />
                        </div>
                    </div>

                    <div className="space-y-3">
                        <div className="flex justify-between items-center px-1">
                            <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em]">Mot de passe</label>
                            <button
                                type="button"
                                onClick={onForgotPassword}
                                className="text-[10px] font-black text-[#00C88C] uppercase tracking-widest hover:brightness-125 transition-all"
                            >
                                Mot de passe oublié ?
                            </button>
                        </div>
                        <div className="relative group">
                            <Lock className="absolute left-5 top-1/2 -translate-y-1/2 text-slate-700 group-focus-within:text-[#00C88C] transition-colors" size={20} />
                            <input
                                type={showPassword ? 'text' : 'password'}
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                placeholder="••••••••"
                                className="w-full bg-[#0D1B17] border border-[#1A2E28] rounded-[1.25rem] py-5 pl-14 pr-4 text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold text-sm"
                            />
                            <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute right-5 top-1/2 -translate-y-1/2 text-slate-700 hover:text-white transition-colors">
                                {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                            </button>
                        </div>
                    </div>

                    <div className="flex items-center space-x-4 px-1">
                        <input
                            type="checkbox"
                            id="rem"
                            checked={rememberMe}
                            onChange={(e) => setRememberMe(e.target.checked)}
                            className="w-5 h-5 rounded-lg border-[#1A2E28] bg-[#0D1B17] text-[#00C88C] focus:ring-[#00C88C]/20 border-2"
                        />
                        <label htmlFor="rem" className="text-xs text-slate-500 font-bold cursor-pointer">Rester connecté pendant 30 jours</label>
                    </div>

                    <button type="submit" disabled={loading} className="w-full btn-primary group py-5 shadow-2xl disabled:opacity-60">
                        {loading ? (
                            <Loader2 size={22} className="animate-spin" />
                        ) : (
                            <>
                                <span className="tracking-[0.2em] font-black">SE CONNECTER</span>
                                <ArrowRight size={22} className="group-hover:translate-x-2 transition-transform ml-2" />
                            </>
                        )}
                    </button>
                </form>

                <div className="mt-16 text-center">
                    <p className="text-xs text-slate-600 font-bold uppercase tracking-widest">
                        Problème d'accès ? <button onClick={onSupport} className="text-white hover:text-[#00C88C] transition-colors underline underline-offset-8 decoration-[#152924]">Contacter le support IT</button>
                    </p>
                </div>
            </div>
        </div>
    </div>
    );
};

export default LoginView;
