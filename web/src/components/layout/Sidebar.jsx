import React, { useContext } from 'react';
import {
    LayoutDashboard,
    Users,
    BookOpen,
    FileText,
    BarChart3,
    Settings,
    LogOut,
    Plus
} from 'lucide-react';
import { AuthContext } from '../../App';

const SidebarItem = ({ id, icon: Icon, label, activeTab, onClick }) => {
    const isActive = activeTab === id;
    return (
        <button
            onClick={() => onClick(id)}
            className={`sidebar-item w-full mb-2 ${isActive ? 'sidebar-item-active' : 'text-slate-400 hover:bg-[#11241E] hover:text-[#00C88C]'
                }`}
        >
            <Icon size={20} />
            <span className="font-bold tracking-tight">{label}</span>
            {isActive && <div className="ml-auto w-1.5 h-1.5 rounded-full bg-white shadow-[0_0_8px_white]"></div>}
        </button>
    );
};

const Sidebar = ({ activeTab, onTabChange, onLogout }) => {
    const { adminUser } = useContext(AuthContext) || {};
    const displayName = adminUser?.full_name || adminUser?.email || 'Admin';
    const avatarUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=00C88C&color=fff`;

    return (
        <aside className="w-80 bg-[#081310] border-r border-[#152924] flex flex-col p-8 h-full">
            <div className="flex items-center space-x-4 mb-14 px-2">
                <div className="w-12 h-12 bg-[#00C88C] rounded-2xl flex items-center justify-center shadow-[0_0_20px_rgba(0,200,140,0.4)]">
                    <Plus className="text-[#050C0A]" size={28} />
                </div>
                <div>
                    <h1 className="text-white font-black leading-tight uppercase tracking-wider text-base">Dica Clinic</h1>
                    <p className="text-[#00C88C] text-[10px] font-black uppercase tracking-[0.3em]">Administration</p>
                </div>
            </div>

            <nav className="flex-1 space-y-1">
                <SidebarItem id="dashboard" icon={LayoutDashboard} label="Dashboard" activeTab={activeTab} onClick={onTabChange} />
                <SidebarItem id="users" icon={Users} label="Utilisateurs" activeTab={activeTab} onClick={onTabChange} />
                <SidebarItem id="cases" icon={BookOpen} label="Cas Cliniques" activeTab={activeTab} onClick={onTabChange} />
                <SidebarItem id="courses" icon={FileText} label="Quiz" activeTab={activeTab} onClick={onTabChange} />
                <SidebarItem id="analytics" icon={BarChart3} label="Analytique" activeTab={activeTab} onClick={onTabChange} />

                <div className="mt-12 pt-10 border-t border-[#152924]">
                    <p className="text-[10px] uppercase tracking-[0.3em] text-slate-600 mb-6 px-4 font-black">SYSTÈME</p>
                    <SidebarItem id="settings" icon={Settings} label="Paramètres" activeTab={activeTab} onClick={onTabChange} />
                </div>
            </nav>

            <div className="mt-auto pt-8">
                <div className="flex items-center space-x-4 p-4 bg-[#0D1B17] rounded-[1.5rem] border border-[#1A2E28] shadow-2xl group transition-all hover:border-[#00C88C]/30">
                    <div className="w-12 h-12 rounded-2xl overflow-hidden border-2 border-[#00C88C]/30 group-hover:border-[#00C88C] transition-all">
                        <img src={avatarUrl} alt="Profile" className="w-full h-full object-cover" />
                    </div>
                    <div className="flex-1 overflow-hidden">
                        <p className="text-sm font-black text-white truncate tracking-tight">{displayName}</p>
                        <p className="text-[10px] text-[#00C88C] font-black uppercase tracking-widest">Admin</p>
                    </div>
                    <button onClick={onLogout} className="p-2.5 bg-[#050C0A] rounded-xl text-slate-500 hover:text-rose-500 hover:bg-rose-500/10 transition-all border border-[#1A2E28]">
                        <LogOut size={16} />
                    </button>
                </div>
            </div>
        </aside>
    );
};

export default Sidebar;
