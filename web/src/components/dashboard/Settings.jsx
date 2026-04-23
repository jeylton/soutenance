import React, { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Cpu, Shield, Globe, Power, Clock, ChevronDown, CheckCircle2, Loader2 } from 'lucide-react';

const ConfigSection = ({ title, icon: Icon, children }) => (
    <div className="space-y-6">
        <div className="flex items-center space-x-3 text-white">
            <div className="p-2.5 bg-[#11241E] rounded-xl text-[#00C88C] border border-[#1A2E28] shadow-lg">
                <Icon size={18} />
            </div>
            <h3 className="text-xl font-black tracking-tight">{title}</h3>
        </div>
        <div className="stat-card p-10 bg-gradient-to-br from-[#0D1B17] to-[#050C0A]">
            {children}
        </div>
    </div>
);

const InputField = ({ label, placeholder, type = "text", icon: Icon, value, onChange }) => (
    <div className="space-y-4">
        <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">{label}</label>
        <div className="relative group">
            {Icon && <Icon className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-700 group-focus-within:text-[#00C88C] transition-colors" size={18} />}
            <input
                type={type}
                value={value || ''}
                onChange={(e) => onChange(e.target.value)}
                placeholder={placeholder}
                className={`w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 ${Icon ? 'pl-16' : 'px-8'} pr-8 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold placeholder:text-slate-800 shadow-inner`}
            />
        </div>
    </div>
);

const SelectField = ({ label, options, value, onChange }) => (
    <div className="space-y-4">
        <label className="block text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] px-1">{label}</label>
        <div className="relative group">
            <select
                className="w-full bg-[#050C0A] border border-[#1A2E28] rounded-2xl py-5 px-8 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold appearance-none cursor-pointer shadow-inner"
                value={value || ''}
                onChange={(e) => onChange(e.target.value)}
            >
                {options.map(opt => <option key={opt} value={opt}>{opt}</option>)}
            </select>
            <ChevronDown className="absolute right-6 top-1/2 -translate-y-1/2 text-slate-600 pointer-events-none group-focus-within:text-[#00C88C] transition-colors" size={20} />
        </div>
    </div>
);

const ToggleField = ({ label, description, checked, onToggle }) => (
    <div className="flex items-center justify-between p-6 bg-[#050C0A] rounded-3xl border border-[#1A2E28]/50 shadow-inner group">
        <div>
            <h5 className="font-black text-white tracking-tight mb-1">{label}</h5>
            <p className="text-[10px] text-slate-600 font-bold leading-relaxed">{description}</p>
        </div>
        <button
            onClick={onToggle}
            className={`w-14 h-8 rounded-full relative transition-all duration-300 ${checked ? 'bg-[#00C88C] shadow-[0_0_15px_rgba(0,200,140,0.4)]' : 'bg-slate-800'}`}
        >
            <div className={`absolute top-1 w-6 h-6 bg-white rounded-full transition-all duration-300 shadow-xl ${checked ? 'right-1' : 'left-1'}`}></div>
        </button>
    </div>
);

const Settings = ({ token }) => {
    const api = import.meta.env.VITE_API_URL;
    const [saving, setSaving] = useState(false);
    const [saved, setSaved] = useState(false);
    const [settings, setSettings] = useState({
        site_title: 'Dica Clinic Administration',
        maintenance_mode: 'false',
        ollama_url: 'http://localhost:11434',
        llm_model: 'MedLlama-2 (13b)',
        password_policy: 'Strict (Maj, Min, Chiffre, Symbole)',
        session_timeout: '30',
    });

    useEffect(() => {
        const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
        fetch(`${api}/api/settings`, { headers })
            .then(r => r.json())
            .then(data => {
                if (data && typeof data === 'object') {
                    setSettings(prev => ({ ...prev, ...data }));
                }
            })
            .catch(() => {});
    }, []);

    const update = (key, value) => setSettings(prev => ({ ...prev, [key]: value }));

    const handleSave = async () => {
        setSaving(true);
        setSaved(false);
        try {
            const headers = { 'Content-Type': 'application/json' };
            if (token) headers['Authorization'] = `Bearer ${token}`;
            await fetch(`${api}/api/settings`, {
                method: 'PUT',
                headers,
                body: JSON.stringify(settings),
            });
            setSaved(true);
            setTimeout(() => setSaved(false), 3000);
        } catch {}
        setSaving(false);
    };

    const handleReset = () => {
        setSettings({
            site_title: 'Dica Clinic Administration',
            maintenance_mode: 'false',
            ollama_url: 'http://localhost:11434',
            llm_model: 'MedLlama-2 (13b)',
            password_policy: 'Strict (Maj, Min, Chiffre, Symbole)',
            session_timeout: '30',
        });
    };

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-16 pb-20">
            {/* General Settings */}
            <ConfigSection title="Paramètres Généraux" icon={Globe}>
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
                    <InputField label="Titre du Site" value={settings.site_title} onChange={(v) => update('site_title', v)} placeholder="Nom du portail..." />
                    <ToggleField
                        label="Mode Maintenance"
                        description="Désactiver l'accès public au portail"
                        checked={settings.maintenance_mode === 'true'}
                        onToggle={() => update('maintenance_mode', settings.maintenance_mode === 'true' ? 'false' : 'true')}
                    />
                </div>
            </ConfigSection>

            {/* AI & Models */}
            <ConfigSection title="IA & Modèles" icon={Cpu}>
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
                    <InputField
                        label="Ollama URL"
                        value={settings.ollama_url}
                        onChange={(v) => update('ollama_url', v)}
                        placeholder="Endpoint de l'IA locale..."
                        icon={Power}
                    />
                    <SelectField
                        label="Sélection du Modèle"
                        options={['MedLlama-2 (13b)', 'Llama-3 (8b)', 'Mistral-Medical (7b)']}
                        value={settings.llm_model}
                        onChange={(v) => update('llm_model', v)}
                    />
                </div>
            </ConfigSection>

            {/* Security */}
            <ConfigSection title="Sécurité" icon={Shield}>
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
                    <SelectField
                        label="Politique de Mot de Passe"
                        options={['Strict (Maj, Min, Chiffre, Symbole)', 'Moyen', 'Standard']}
                        value={settings.password_policy}
                        onChange={(v) => update('password_policy', v)}
                    />
                    <InputField
                        label="Timeout de Session (Min)"
                        value={settings.session_timeout}
                        onChange={(v) => update('session_timeout', v)}
                        placeholder="Minutes avant déconnexion..."
                        icon={Clock}
                    />
                </div>
            </ConfigSection>

            {/* Actions */}
            <div className="flex items-center justify-end space-x-6 pt-4">
                {saved && (
                    <span className="text-sm font-bold text-[#00C88C] animate-in fade-in duration-300">
                        Paramètres sauvegardés !
                    </span>
                )}
                <button
                    onClick={handleReset}
                    className="px-10 py-4.5 rounded-[1.25rem] border border-[#1A2E28] text-slate-500 font-black uppercase text-[10px] tracking-widest hover:text-white hover:bg-[#11241E] transition-all"
                >
                    Réinitialiser
                </button>
                <button onClick={handleSave} disabled={saving} className="btn-primary px-10 py-5 group shadow-2xl disabled:opacity-60">
                    {saving ? (
                        <Loader2 size={20} className="animate-spin mr-2" />
                    ) : (
                        <CheckCircle2 size={20} className="mr-2 group-hover:scale-110 transition-transform" />
                    )}
                    <span className="font-black tracking-widest uppercase">Sauvegarder les modifications</span>
                </button>
            </div>
        </div>
    );
};

export default Settings;
