import React, { useEffect, useState } from 'react';
import { Eye, MoreVertical, Search } from 'lucide-react';

const AVATAR_EMOJIS = {
    avatar_docteur: '👨‍⚕️',
    avatar_chirurgien: '🧑‍⚕️',
    avatar_scientifique: '🔬',
    avatar_gold: '🖼️',
    avatar_ninja: '🥷',
    avatar_diamond: '💎',
    avatar_robot: '🤖',
    avatar_crown: '👑',
};

const INITIALS_COLORS = [
    'bg-[#00C88C]', 'bg-blue-500', 'bg-purple-500', 'bg-amber-500',
    'bg-rose-500', 'bg-cyan-500', 'bg-indigo-500', 'bg-teal-500',
];

const getInitials = (name) => {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/);
    if (parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    return name[0].toUpperCase();
};

const toNumber = (v) => {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
};

const UserCard = ({
    name,
    role,
    cases,
    succ,
    online,
    idx,
    avatarId,
    onView,
    onToggleMenu,
    showMenu,
    onCopyEmail,
    onEmail,
}) => {
    const emoji = avatarId ? AVATAR_EMOJIS[avatarId] : null;
    const initials = getInitials(name);
    const colorClass = INITIALS_COLORS[idx % INITIALS_COLORS.length];

    return (
    <div className="stat-card flex items-center p-5 group hover:bg-[#11241E]/50 transition-all border-[#1A2E28] hover:border-[#00C88C]/30">
        <div className="relative mr-6">
            <div className="w-16 h-16 rounded-2xl overflow-hidden border border-[#1A2E28] shadow-lg flex items-center justify-center bg-[#0D1B17]">
                {emoji ? (
                    <span className="text-3xl">{emoji}</span>
                ) : (
                    <div className={`w-full h-full flex items-center justify-center ${colorClass}`}>
                        <span className="text-xl font-black text-white">{initials}</span>
                    </div>
                )}
            </div>
            <div className={`absolute -bottom-1 -right-1 w-4.5 h-4.5 border-4 border-[#0D1B17] rounded-full ${online ? 'bg-[#00C88C] shadow-[0_0_10px_#00C88C]' : 'bg-slate-600'}`}></div>
        </div>

        <div className="flex-1 min-w-0">
            <div className="flex items-center space-x-2 mb-1.5">
                <h5 className="text-sm font-black text-white group-hover:text-[#00C88C] transition-colors truncate tracking-tight">{name}</h5>
                <span className={`text-[8px] font-black uppercase px-2 py-0.5 rounded-md ${role === 'Docteur' ? 'bg-[#00C88C]/10 text-[#00C88C]' :
                        role === 'Étudiant' ? 'bg-blue-500/10 text-blue-400' :
                            'bg-amber-500/10 text-amber-500'
                    }`}>
                    {role}
                </span>
            </div>
            <div className="flex space-x-6">
                <div>
                    <p className="text-[9px] text-slate-500 uppercase font-black tracking-widest mb-0.5">Cas</p>
                    <p className="text-xs font-black text-white">{cases}</p>
                </div>
                <div>
                    <p className="text-[9px] text-slate-500 uppercase font-black tracking-widest mb-0.5">Succès</p>
                    <p className="text-xs font-black text-[#00C88C]">{succ}</p>
                </div>
            </div>
        </div>

        <div className="relative flex items-center space-x-1 ml-4">
            <button onClick={onView} className="p-2.5 transition-all bg-[#050C0A] hover:bg-[#11241E] rounded-xl text-slate-500 hover:text-white border border-[#1A2E28]">
                <Eye size={18} />
            </button>
            <button onClick={onToggleMenu} className="p-2.5 transition-all bg-[#050C0A] hover:bg-[#11241E] rounded-xl text-slate-500 hover:text-white border border-[#1A2E28]">
                <MoreVertical size={18} />
            </button>
            {showMenu && (
                <div className="absolute right-0 top-12 z-20 min-w-[170px] rounded-xl border border-[#1A2E28] bg-[#08110E] p-1.5 shadow-2xl">
                    <button
                        onClick={onView}
                        className="w-full rounded-lg px-3 py-2 text-left text-xs font-bold text-slate-200 hover:bg-[#11241E]"
                    >
                        Voir détails
                    </button>
                    <button
                        onClick={onCopyEmail}
                        className="w-full rounded-lg px-3 py-2 text-left text-xs font-bold text-slate-200 hover:bg-[#11241E]"
                    >
                        Copier email
                    </button>
                    <button
                        onClick={onEmail}
                        className="w-full rounded-lg px-3 py-2 text-left text-xs font-bold text-slate-200 hover:bg-[#11241E]"
                    >
                        Envoyer un email
                    </button>
                </div>
            )}
        </div>
    </div>
    );
};

const UserManagement = () => {
    const [status, setStatus] = useState('');
    const [users, setUsers] = useState([]);
    const [sessions, setSessions] = useState([]);
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedUser, setSelectedUser] = useState(null);
    const [menuForUserId, setMenuForUserId] = useState(null);

    useEffect(() => {
        const api = import.meta.env.VITE_API_URL;
        const usersUrl = status ? `${api}/api/users?status=${status}` : `${api}/api/users`;
        Promise.all([
            fetch(usersUrl).then((res) => res.json()),
            fetch(`${api}/api/sessions`).then((res) => res.json()).catch(() => ({ sessions: [] })),
        ])
            .then(([usersData, sessionsData]) => {
                setUsers(usersData.users || []);
                setSessions(sessionsData.sessions || []);
            })
            .catch(() => {
                setUsers([]);
                setSessions([]);
            });
    }, [status]);

    useEffect(() => {
        const onBodyClick = () => setMenuForUserId(null);
        window.addEventListener('click', onBodyClick);
        return () => window.removeEventListener('click', onBodyClick);
    }, []);

    const sessionStatsByUser = sessions.reduce((acc, s) => {
        const userId = s?.user_id;
        if (!userId) return acc;
        if (!acc[userId]) {
            acc[userId] = {
                attempts: 0,
                completed: 0,
                success: 0,
                totalScore: 0,
            };
        }
        acc[userId].attempts += 1;
        const score = s?.score;
        if (score !== null && score !== undefined) {
            const scoreNum = toNumber(score);
            acc[userId].completed += 1;
            acc[userId].totalScore += scoreNum;
            if (scoreNum >= 10) acc[userId].success += 1;
        }
        return acc;
    }, {});

    const filteredUsers = users.filter((u) => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (u.full_name || '').toLowerCase().includes(q) || (u.email || '').toLowerCase().includes(q) || (u.profile_type || '').toLowerCase().includes(q);
    });

    const withStats = filteredUsers.map((u) => {
        const stats = sessionStatsByUser[u.id] || { attempts: 0, completed: 0, success: 0, totalScore: 0 };
        const successRate = stats.completed > 0 ? Math.round((stats.success / stats.completed) * 100) : 0;
        return {
            ...u,
            _stats: {
                ...stats,
                successRate,
                avgScore: stats.completed > 0 ? (stats.totalScore / stats.completed) : 0,
            },
        };
    });

    return (
        <div className="animate-in fade-in slide-in-from-right-4 duration-500 space-y-10">
            {/* Header with Search and Tabs */}
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6 pb-2">
                <div className="flex flex-1 max-w-2xl">
                    <div className="relative w-full group">
                        <Search className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-600 group-focus-within:text-[#00C88C] transition-colors" size={20} />
                        <input
                            type="text"
                            placeholder="Rechercher un utilisateur, un rôle..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="w-full bg-[#0D1B17] border border-[#1A2E28] rounded-[1.5rem] py-5 pl-16 pr-8 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold placeholder:text-slate-700 shadow-inner"
                        />
                    </div>
                </div>

                <div className="flex items-center gap-3">
                    <select
                        value={status}
                        onChange={(e) => setStatus(e.target.value)}
                        className="bg-[#0D1B17] border border-[#1A2E28] rounded-[1.5rem] py-3 px-4 text-sm text-white focus:outline-none focus:border-[#00C88C]/40 transition-all font-bold"
                    >
                        <option value="">Tous</option>
                        <option value="etudiant">Étudiant</option>
                        <option value="medecin">Médecin</option>
                        <option value="interne">Interne</option>
                        <option value="autre">Autre</option>
                    </select>
                </div>
            </div>

            <div className="text-[10px] text-slate-500 uppercase font-black tracking-widest">Utilisateurs créés via l’application mobile</div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                {withStats.length === 0 ? (
                    <div className="p-4 text-slate-500">{searchQuery ? 'Aucun résultat pour cette recherche' : '0 utilisateur'}</div>
                ) : (
                    withStats.map((u, idx) => (
                        <UserCard
                            key={u.id || idx}
                            name={u.full_name || u.email || 'Utilisateur'}
                            role={
                                u.profile_type === 'medecin'
                                    ? 'Docteur'
                                    : u.profile_type === 'etudiant'
                                    ? 'Étudiant'
                                    : u.profile_type === 'interne'
                                    ? 'Interne'
                                    : 'Autre'
                            }
                            cases={u._stats.completed}
                            succ={`${u._stats.successRate}%`}
                            online={false}
                            idx={idx}
                            avatarId={u.avatar_id}
                            onView={() => {
                                setSelectedUser(u);
                                setMenuForUserId(null);
                            }}
                            onToggleMenu={(event) => {
                                event.stopPropagation();
                                setMenuForUserId((curr) => (curr === u.id ? null : u.id));
                            }}
                            showMenu={menuForUserId === u.id}
                            onCopyEmail={() => {
                                if (u.email) navigator.clipboard?.writeText(u.email);
                                setMenuForUserId(null);
                            }}
                            onEmail={() => {
                                if (u.email) window.location.href = `mailto:${u.email}`;
                                setMenuForUserId(null);
                            }}
                        />
                    ))
                )}
            </div>

            {selectedUser && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/65 px-4" onClick={() => setSelectedUser(null)}>
                    <div className="w-full max-w-xl rounded-3xl border border-[#1A2E28] bg-[#09140F] p-6" onClick={(e) => e.stopPropagation()}>
                        <div className="mb-4 flex items-center justify-between">
                            <h3 className="text-lg font-black text-white">Fiche utilisateur</h3>
                            <button className="rounded-lg border border-[#1A2E28] px-3 py-1.5 text-xs font-bold text-slate-300 hover:bg-[#11241E]" onClick={() => setSelectedUser(null)}>
                                Fermer
                            </button>
                        </div>

                        <div className="space-y-3 text-sm">
                            <div className="rounded-xl bg-[#0D1B17] p-3">
                                <p className="text-slate-400">Nom</p>
                                <p className="font-black text-white">{selectedUser.full_name || '—'}</p>
                            </div>
                            <div className="rounded-xl bg-[#0D1B17] p-3">
                                <p className="text-slate-400">Email</p>
                                <p className="font-black text-white">{selectedUser.email || '—'}</p>
                            </div>
                            <div className="grid grid-cols-2 gap-3">
                                <div className="rounded-xl bg-[#0D1B17] p-3">
                                    <p className="text-slate-400">Cas terminés</p>
                                    <p className="font-black text-white">{selectedUser._stats.completed}</p>
                                </div>
                                <div className="rounded-xl bg-[#0D1B17] p-3">
                                    <p className="text-slate-400">Taux de succès</p>
                                    <p className="font-black text-[#00C88C]">{selectedUser._stats.successRate}%</p>
                                </div>
                                <div className="rounded-xl bg-[#0D1B17] p-3">
                                    <p className="text-slate-400">Score moyen</p>
                                    <p className="font-black text-white">{selectedUser._stats.avgScore.toFixed(1)}/20</p>
                                </div>
                                <div className="rounded-xl bg-[#0D1B17] p-3">
                                    <p className="text-slate-400">Tentatives</p>
                                    <p className="font-black text-white">{selectedUser._stats.attempts}</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default UserManagement;
