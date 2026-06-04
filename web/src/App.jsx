import React, { useState, useEffect, createContext } from 'react';
import { Bell } from 'lucide-react';
import Sidebar from './components/layout/Sidebar';
import LoginView from './components/auth/LoginView';
import ForgotPasswordView from './components/auth/ForgotPasswordView';
import SupportView from './components/auth/SupportView';
import Overview from './components/dashboard/Overview';
import UserManagement from './components/dashboard/UserManagement';
import CaseManagement from './components/dashboard/CaseManagement';
import CreateCase from './components/dashboard/CreateCase';
import QuizManagement from './components/dashboard/QuizManagement';
import Analytics from './components/dashboard/Analytics';
import Settings from './components/dashboard/Settings';
import CaseDetail from './components/dashboard/CaseDetail';
import Feedback from './components/dashboard/Feedback';

export const AuthContext = createContext(null);

function App() {
    const apiBase = (() => {
        const env = String(import.meta.env.VITE_API_URL || '').trim().replace(/\/+$/, '');
        if (env) return env;
        const hostname = typeof window !== 'undefined' ? String(window.location?.hostname || '') : '';
        const protocol = typeof window !== 'undefined' ? String(window.location?.protocol || '') : '';
        if (hostname === 'localhost' || hostname === '127.0.0.1') return 'http://127.0.0.1:5000';
        if (protocol === 'file:') return 'http://127.0.0.1:5000';
        return typeof window !== 'undefined' ? String(window.location.origin || '').replace(/\/+$/, '') : '';
    })();
    const [token, setToken] = useState(() => localStorage.getItem('dica_token'));
    const [adminUser, setAdminUser] = useState(() => {
        try { return JSON.parse(localStorage.getItem('dica_user')); } catch { return null; }
    });
    const [currentScreen, setCurrentScreen] = useState('login');
    const [activeTab, setActiveTab] = useState('dashboard');
    const [selectedCaseId, setSelectedCaseId] = useState(null);
    const [editCaseData, setEditCaseData] = useState(null);
    const [createCasePresetSpecialtyId, setCreateCasePresetSpecialtyId] = useState(null);
    const [createCasePresetSeason, setCreateCasePresetSeason] = useState(null);
    const [createCasePresetEpisode, setCreateCasePresetEpisode] = useState(null);

    // Validate stored token on mount — redirect to login if invalid/expired
    useEffect(() => {
        const savedToken = localStorage.getItem('dica_token');
        if (!savedToken) { setCurrentScreen('login'); return; }
        fetch(`${apiBase}/api/auth/me`, {
            headers: { 'Authorization': `Bearer ${savedToken}` },
        })
            .then(r => {
                if (!r.ok) throw new Error('Token invalide');
                return r.json();
            })
            .then(data => {
                if (data.user?.role === 'admin' || data.user?.role === 'teacher') {
                    setToken(savedToken);
                    setAdminUser(data.user);
                    setCurrentScreen('dashboard-main');
                } else {
                    throw new Error('Accès non autorisé');
                }
            })
            .catch(() => {
                localStorage.removeItem('dica_token');
                localStorage.removeItem('dica_user');
                setToken(null);
                setAdminUser(null);
                setCurrentScreen('login');
            });
    }, [apiBase]);

    const handleLogin = (jwt, user) => {
        setToken(jwt);
        setAdminUser(user);
        localStorage.setItem('dica_token', jwt);
        localStorage.setItem('dica_user', JSON.stringify(user));
        setCurrentScreen('dashboard-main');
    };
    const handleLogout = () => {
        setToken(null);
        setAdminUser(null);
        localStorage.removeItem('dica_token');
        localStorage.removeItem('dica_user');
        setCurrentScreen('login');
        setActiveTab('dashboard');
    };

    // Helper: auth headers for fetch calls
    const authHeaders = token ? { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' } : { 'Content-Type': 'application/json' };

    const getTitle = () => {
        switch (activeTab) {
            case 'dashboard': return "Dashboard";
            case 'users': return "Gestion des Utilisateurs";
            case 'cases': return "Gestion des Cas";
            case 'create-case': return "Création de Cas";
            case 'edit-case': return "Modification du Cas";
            case 'courses': return "Gestion des Quiz";
            case 'analytics': return "Analytique";
            case 'case-detail': return "Détail du Cas";
            case 'feedback': return "Feedback Tuteur";
            case 'settings': return "Paramètres";
            default: return "Administration";
        }
    };

    // Auth Screens
    if (currentScreen === 'login') {
        return <LoginView onLogin={handleLogin} onForgotPassword={() => setCurrentScreen('forgot-password')} onSupport={() => setCurrentScreen('support')} />;
    }
    if (currentScreen === 'forgot-password') {
        return <ForgotPasswordView onBack={() => setCurrentScreen('login')} />;
    }
    if (currentScreen === 'support') {
        return <SupportView onBack={() => setCurrentScreen('login')} />;
    }

    // Dashboard Main
    return (
        <AuthContext.Provider value={{ token, authHeaders, adminUser, handleLogout }}>
        <div className="flex h-screen overflow-hidden bg-[#050C0A] text-slate-200 select-none">
            <Sidebar
                activeTab={activeTab === 'create-case' || activeTab === 'edit-case' ? 'cases' : activeTab}
                onTabChange={(tab) => setActiveTab(tab)}
                onLogout={handleLogout}
            />

            <main className="flex-1 overflow-y-auto custom-scrollbar flex flex-col">
                {/* Only show header if not in a "Create" screen (optional, but let's keep it consistent with mockup) */}
                {!(activeTab === 'create-case' || activeTab === 'edit-case') && (
                    <header className="h-28 border-b border-[#152924] flex items-center justify-between px-12 sticky top-0 bg-[#050C0A]/80 backdrop-blur-2xl z-20">
                        <div className="space-y-1">
                            <p className="text-[10px] text-[#00C88C] font-black uppercase tracking-[.3em]">Dica Clinic Admin</p>
                            <h2 className="text-4xl font-black text-white tracking-tight">{getTitle()}</h2>
                        </div>

                        <div className="flex items-center space-x-6">
                            {adminUser && (
                                <span className="text-xs font-bold text-slate-400">{adminUser.full_name || adminUser.email}</span>
                            )}
                            <div className="relative p-3.5 bg-[#0D1B17] border border-[#1A2E28] rounded-2xl text-slate-400 hover:text-[#00C88C] transition-all cursor-pointer shadow-xl group">
                                <Bell size={24} className="group-hover:animate-swing" />
                                <span className="absolute top-3.5 right-3.5 w-3 h-3 bg-[#00C88C] border-2 border-[#0D1B17] rounded-full shadow-[0_0_8px_#00C88C]"></span>
                            </div>
                        </div>
                    </header>
                )}

                <div className={`${(activeTab === 'create-case' || activeTab === 'edit-case') ? 'p-0' : 'p-12'} flex-1 relative max-w-[1600px] w-full mx-auto`}>
                    {activeTab === 'dashboard' && <Overview />}
                    {activeTab === 'users' && <UserManagement />}
                    {activeTab === 'cases' && (
                        <CaseManagement
                            onCreateNew={(specialtyId, season, episode) => {
                                setCreateCasePresetSpecialtyId(specialtyId ?? null);
                                setCreateCasePresetSeason(season ?? null);
                                setCreateCasePresetEpisode(episode ?? null);
                                setActiveTab('create-case');
                            }}
                            onViewCase={(id) => {
                                setSelectedCaseId(id);
                                setActiveTab('case-detail');
                            }}
                            onEditCase={(caseData) => {
                                setEditCaseData(caseData);
                                setActiveTab('edit-case');
                            }}
                        />
                    )}
                    {activeTab === 'create-case' && (
                        <CreateCase
                            onBack={() => {
                                setCreateCasePresetSpecialtyId(null);
                                setCreateCasePresetSeason(null);
                                setCreateCasePresetEpisode(null);
                                setActiveTab('cases');
                            }}
                            presetSpecialtyId={createCasePresetSpecialtyId}
                            presetSeason={createCasePresetSeason}
                            presetEpisode={createCasePresetEpisode}
                        />
                    )}
                    {activeTab === 'edit-case' && (
                        <CreateCase
                            onBack={() => {
                                setEditCaseData(null);
                                setActiveTab('cases');
                            }}
                            editData={editCaseData}
                        />
                    )}
                    {activeTab === 'case-detail' && <CaseDetail caseId={selectedCaseId} onBack={() => setActiveTab('cases')} />}
                    {activeTab === 'courses' && <QuizManagement />}
                    {activeTab === 'analytics' && <Analytics />}
                    {activeTab === 'settings' && <Settings token={token} />}
                    {activeTab === 'feedback' && <Feedback onBack={() => setActiveTab('dashboard')} />}
                </div>
            </main>
        </div>
        </AuthContext.Provider>
    );
}

export default App;
