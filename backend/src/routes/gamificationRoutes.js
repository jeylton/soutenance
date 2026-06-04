const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// ─── Purchases file store (no DDL needed) ───
const PURCHASES_FILE = path.join(__dirname, '../../data/purchases.json');
const QUIZ_ATTEMPTS_FILE = path.join(__dirname, '../../data/quiz_attempts.json');

function starsFromCaseScore(score20) {
  const s = Math.max(0, Math.min(20, Number(score20) || 0));
  if (s >= 17) return 3;
  if (s >= 12) return 2;
  if (s > 0) return 1;
  return 0;
}

function starsFromQuizAccuracy(accuracy) {
  const a = Math.max(0, Math.min(1, Number(accuracy) || 0));
  if (a <= 0) return 0;
  if (a >= 0.85) return 3;
  if (a >= 0.60) return 2;
  return 1;
}

function computeQuizTrophies(attempts) {
  const bestByKey = new Map();
  for (const entry of Array.isArray(attempts) ? attempts : []) {
    const quizKey = String(entry?.quiz_key || '').trim();
    if (!quizKey) continue;

    let accuracy = Number(entry?.accuracy);
    if (!Number.isFinite(accuracy) || accuracy <= 0) {
      const good = Number(entry?.score) || 0;
      const total = Number(entry?.total) || 0;
      accuracy = total > 0 ? (good / total) : 0;
    }
    const stars = starsFromQuizAccuracy(accuracy);
    const prev = bestByKey.get(quizKey) || 0;
    if (stars > prev) bestByKey.set(quizKey, stars);
  }
  let sum = 0;
  for (const v of bestByKey.values()) sum += v;
  return sum;
}

async function computeTrophiesForUser(userId) {
  const uid = String(userId || '').trim();
  if (!uid) return { trophies: 0, cases: 0, quiz: 0 };

  // Cases: best score per case_id → stars.
  const { data: sessions } = await supabase
    .from('sessions')
    .select('case_id,score')
    .eq('user_id', uid)
    .not('score', 'is', null);

  const bestScoreByCaseId = new Map();
  for (const s of Array.isArray(sessions) ? sessions : []) {
    const caseId = Number(s?.case_id) || 0;
    if (caseId <= 0) continue;
    const score = Number(s?.score) || 0;
    const prev = bestScoreByCaseId.get(caseId);
    if (prev == null || score > prev) bestScoreByCaseId.set(caseId, score);
  }
  let caseTrophies = 0;
  for (const best of bestScoreByCaseId.values()) {
    caseTrophies += starsFromCaseScore(best);
  }

  // Quiz: best accuracy per quiz_key → stars.
  const attemptsDb = loadQuizAttempts();
  const quizAttempts = Array.isArray(attemptsDb[uid]) ? attemptsDb[uid] : [];
  const quizTrophies = computeQuizTrophies(quizAttempts);

  return { trophies: caseTrophies + quizTrophies, cases: caseTrophies, quiz: quizTrophies };
}

function levelFromTrophies(trophies) {
  const t = Math.max(0, Number(trophies) || 0);
  return Math.floor(t / 10) + 1;
}

function computeCaseTrophiesFromSessions(sessions) {
  const bestByUserCase = new Map();
  for (const row of Array.isArray(sessions) ? sessions : []) {
    const userId = String(row?.user_id || '').trim();
    const caseId = Number(row?.case_id) || 0;
    if (!userId || caseId <= 0) continue;
    const key = `${userId}:${caseId}`;
    const score = Number(row?.score) || 0;
    const prev = bestByUserCase.get(key);
    if (prev == null || score > prev) bestByUserCase.set(key, score);
  }

  const totals = new Map();
  for (const [key, bestScore] of bestByUserCase.entries()) {
    const userId = key.split(':')[0];
    totals.set(userId, (totals.get(userId) || 0) + starsFromCaseScore(bestScore));
  }
  return totals;
}

function chunkArray(values, chunkSize) {
  const size = Math.max(1, Number(chunkSize) || 1);
  const chunks = [];
  for (let i = 0; i < values.length; i += size) {
    chunks.push(values.slice(i, i + size));
  }
  return chunks;
}

function loadPurchases() {
  try { return JSON.parse(fs.readFileSync(PURCHASES_FILE, 'utf8')); }
  catch { return {}; }
}

function savePurchases(data) {
  fs.mkdirSync(path.dirname(PURCHASES_FILE), { recursive: true });
  fs.writeFileSync(PURCHASES_FILE, JSON.stringify(data, null, 2));
}

function loadQuizAttempts() {
  try { return JSON.parse(fs.readFileSync(QUIZ_ATTEMPTS_FILE, 'utf8')); }
  catch { return {}; }
}

function saveQuizAttempts(data) {
  fs.mkdirSync(path.dirname(QUIZ_ATTEMPTS_FILE), { recursive: true });
  fs.writeFileSync(QUIZ_ATTEMPTS_FILE, JSON.stringify(data, null, 2));
}

// ─── GET /api/gamification/me — Get XP, level, badges for current user ───
router.get('/me', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: xp } = await supabase.from('user_xp').select('xp,level').eq('user_id', userId).single();
    const { data: badges } = await supabase
      .from('user_badges')
      .select('earned_at,badges(id,name,description,icon)')
      .eq('user_id', userId);

    // Trophies = stars from best case scores + best quiz accuracies (no bonus).
    const trophyTotals = await computeTrophiesForUser(userId);
    const trophiesLevel = levelFromTrophies(trophyTotals.trophies);

    // Keep DB level in sync (XP remains currency only).
    try {
      const existing = await supabase.from('user_xp').select('xp,level').eq('user_id', userId).single();
      if (!existing?.data) {
        await supabase.from('user_xp').insert([{ user_id: userId, xp: 0, level: trophiesLevel }]);
      } else {
        await supabase
          .from('user_xp')
          .update({ level: trophiesLevel, updated_at: new Date().toISOString() })
          .eq('user_id', userId);
      }
    } catch (_) {}

    return res.json({
      xp: xp?.xp || 0,
      level: trophiesLevel,
      trophies: trophyTotals.trophies,
      trophies_cases: trophyTotals.cases,
      trophies_quiz: trophyTotals.quiz,
      badges: (badges || []).map(b => ({ ...b.badges, earned_at: b.earned_at })),
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── GET /api/gamification/leaderboard — Top users by trophies ───
router.get('/leaderboard', async (_req, res) => {
  try {
    // Fetch all users with XP rows (used for currency + level metadata).
    const allXpRows = [];
    const pageSize = 1000;
    for (let from = 0; ; from += pageSize) {
      const { data, error } = await supabase
        .from('user_xp')
        .select('xp,level,user_id,users(full_name,profile_type)')
        .range(from, from + pageSize - 1);
      if (error) return res.status(500).json({ error: error.message });
      allXpRows.push(...(data || []));
      if (!data || data.length < pageSize) break;
    }

    const userIds = allXpRows.map((r) => r.user_id).filter(Boolean);

    if (userIds.length === 0) {
      return res.json({ leaderboard: [] });
    }

    // Fetch sessions for those users and compute best-stars trophies for cases.
    const allSessions = [];
    const userChunks = chunkArray(userIds, 200);
    for (const chunk of userChunks) {
      for (let from = 0; ; from += pageSize) {
        const { data, error } = await supabase
          .from('sessions')
          .select('user_id,case_id,score')
          .in('user_id', chunk)
          .not('score', 'is', null)
          .range(from, from + pageSize - 1);
        if (error) return res.status(500).json({ error: error.message });
        allSessions.push(...(data || []));
        if (!data || data.length < pageSize) break;
      }
    }
    const caseTrophiesByUser = computeCaseTrophiesFromSessions(allSessions);

    // Quiz trophies from file store.
    const attemptsDb = loadQuizAttempts();
    const quizTrophiesByUser = new Map();
    for (const id of userIds) {
      const uid = String(id);
      const attempts = Array.isArray(attemptsDb[uid]) ? attemptsDb[uid] : [];
      quizTrophiesByUser.set(uid, computeQuizTrophies(attempts));
    }

    const enriched = allXpRows.map((row) => {
      const uid = String(row.user_id);
      const caseT = caseTrophiesByUser.get(uid) || 0;
      const quizT = quizTrophiesByUser.get(uid) || 0;
      const trophies = caseT + quizT;
      return {
        ...row,
        trophies,
        trophies_cases: caseT,
        trophies_quiz: quizT,
        level: levelFromTrophies(trophies),
      };
    });

    enriched.sort((a, b) => {
      const ta = Number(a.trophies) || 0;
      const tb = Number(b.trophies) || 0;
      if (tb !== ta) return tb - ta;
      const la = Number(a.level) || 1;
      const lb = Number(b.level) || 1;
      if (lb !== la) return lb - la;
      const xa = Number(a.xp) || 0;
      const xb = Number(b.xp) || 0;
      return xb - xa;
    });

    return res.json({ leaderboard: enriched.slice(0, 20) });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── GET /api/gamification/badges — All available badges ───
router.get('/badges', async (_req, res) => {
  try {
    const { data, error } = await supabase.from('badges').select('*').order('id');
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ badges: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── Shop Items (hardcoded catalog) ───
const SHOP_ITEMS = [
  // Titles
  { id: 'title_expert', name: 'Titre: Expert', name_en: 'Title: Expert', description: 'Affiche "Expert" sur votre profil', description_en: 'Display "Expert" on your profile', icon: '🎓', price: 200, category: 'title', minLevel: 1 },
  { id: 'title_master', name: 'Titre: Maître', name_en: 'Title: Master', description: 'Affiche "Maître" sur votre profil', description_en: 'Display "Master" on your profile', icon: '👑', price: 500, category: 'title', minLevel: 3 },
  { id: 'title_legend', name: 'Titre: Légende', name_en: 'Title: Legend', description: 'Affiche "Légende" sur votre profil', description_en: 'Display "Legend" on your profile', icon: '⭐', price: 1000, category: 'title', minLevel: 5 },
  // Avatars
  { id: 'avatar_docteur', name: 'Avatar Docteur', name_en: 'Doctor Avatar', description: 'Avatar professionnel de médecin', description_en: 'Professional doctor avatar', icon: '👨‍⚕️', price: 100, category: 'avatar', minLevel: 1 },
  { id: 'avatar_chirurgien', name: 'Avatar Chirurgien', name_en: 'Surgeon Avatar', description: 'Avatar de chirurgien en bloc', description_en: 'Surgeon in scrubs avatar', icon: '🧑‍⚕️', price: 150, category: 'avatar', minLevel: 1 },
  { id: 'avatar_scientifique', name: 'Avatar Scientifique', name_en: 'Scientist Avatar', description: 'Avatar de chercheur', description_en: 'Researcher avatar', icon: '🔬', price: 200, category: 'avatar', minLevel: 2 },
  { id: 'avatar_gold', name: 'Cadre doré', name_en: 'Gold Frame', description: 'Cadre doré autour de votre avatar', description_en: 'Gold frame around your avatar', icon: '🖼️', price: 300, category: 'avatar', minLevel: 2 },
  { id: 'avatar_ninja', name: 'Avatar Ninja Médical', name_en: 'Medical Ninja Avatar', description: 'Avatar ninja mystérieux', description_en: 'Mysterious ninja avatar', icon: '🥷', price: 400, category: 'avatar', minLevel: 3 },
  { id: 'avatar_diamond', name: 'Cadre diamant', name_en: 'Diamond Frame', description: 'Cadre diamant autour de votre avatar', description_en: 'Diamond frame around your avatar', icon: '💎', price: 750, category: 'avatar', minLevel: 4 },
  { id: 'avatar_robot', name: 'Avatar Robot IA', name_en: 'AI Robot Avatar', description: 'Avatar robot futuriste', description_en: 'Futuristic robot avatar', icon: '🤖', price: 600, category: 'avatar', minLevel: 3 },
  { id: 'avatar_crown', name: 'Avatar Royal', name_en: 'Royal Avatar', description: 'Avatar avec couronne royale', description_en: 'Avatar with royal crown', icon: '👑', price: 1000, category: 'avatar', minLevel: 5 },
  // Consumables
  { id: 'hint_pack_3', name: '3 Indices', name_en: '3 Hints', description: 'Pack de 3 indices utilisables en simulation', description_en: 'Pack of 3 hints for simulations', icon: '💡', price: 150, category: 'consumable', minLevel: 1 },
  { id: 'hint_pack_10', name: '10 Indices', name_en: '10 Hints', description: 'Pack de 10 indices utilisables en simulation', description_en: 'Pack of 10 hints for simulations', icon: '🔦', price: 400, category: 'consumable', minLevel: 2 },
  { id: 'streak_shield', name: 'Bouclier de série', name_en: 'Streak Shield', description: 'Protège votre série en cas d\'échec', description_en: 'Protects your streak on failure', icon: '🛡️', price: 250, category: 'consumable', minLevel: 2 },
  { id: 'xp_boost', name: 'Boost XP x2', name_en: 'XP Boost x2', description: 'Double vos XP pour la prochaine session', description_en: 'Double your XP for the next session', icon: '🚀', price: 350, category: 'consumable', minLevel: 3 },
  // Themes
  { id: 'theme_dark', name: 'Thème sombre', name_en: 'Dark Theme', description: 'Débloquez le thème sombre', description_en: 'Unlock dark theme', icon: '🌙', price: 200, category: 'theme', minLevel: 1 },
];

// ─── GET /api/gamification/shop — List all shop items + user purchases ───
router.get('/shop', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { data: xpRow } = await supabase.from('user_xp').select('xp').eq('user_id', userId).single();
    const xp = xpRow?.xp || 0;

    const allPurchases = loadPurchases();
    const purchases = allPurchases[userId] || [];

    // Get user level (derived from trophies).
    const trophyTotals = await computeTrophiesForUser(userId);
    const userLevel = levelFromTrophies(trophyTotals.trophies);

    const items = SHOP_ITEMS.map(item => ({
      ...item,
      owned: item.category !== 'consumable' ? purchases.includes(item.id) : false,
      count: item.category === 'consumable' ? purchases.filter(p => p === item.id).length : 0,
      locked: (item.minLevel || 1) > userLevel,
    }));

    // Count hint balance
    const hintPurchases = purchases.filter(p => p === 'hint_pack_3' || p === 'hint_pack_10');
    let totalHints = 0;
    for (const hp of hintPurchases) {
      totalHints += hp === 'hint_pack_3' ? 3 : 10;
    }
    // Subtract used hints
    const usedHints = purchases.filter(p => p === 'hint_used').length;
    const hintBalance = Math.max(0, totalHints - usedHints);

    return res.json({ items, xp, purchases, userLevel, hintBalance });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── POST /api/gamification/shop/buy — Purchase an item ───
router.post('/shop/buy', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { itemId } = req.body;

    const item = SHOP_ITEMS.find(i => i.id === itemId);
    if (!item) return res.status(404).json({ error: 'Article introuvable' });

    // Check level requirement (derived from trophies)
    const trophyTotals = await computeTrophiesForUser(userId);
    const userLevel = levelFromTrophies(trophyTotals.trophies);
    if ((item.minLevel || 1) > userLevel) {
      return res.status(403).json({ error: `Niveau ${item.minLevel} requis`, needed_level: item.minLevel, current_level: userLevel });
    }

    const { data: xpRow } = await supabase.from('user_xp').select('xp').eq('user_id', userId).single();
    if (!xpRow) return res.status(400).json({ error: 'Profil XP introuvable' });

    const currentXP = xpRow.xp || 0;
    const allPurchases = loadPurchases();
    const purchases = allPurchases[userId] || [];

    // Check if non-consumable already owned
    if (item.category !== 'consumable' && purchases.includes(itemId)) {
      return res.status(400).json({ error: 'Vous possédez déjà cet article' });
    }

    // Check sufficient XP
    if (currentXP < item.price) {
      return res.status(400).json({ error: 'XP insuffisant', needed: item.price, current: currentXP });
    }

    // Deduct XP (currency only). Level is based on trophies.
    const newXP = currentXP - item.price;

    await supabase
      .from('user_xp')
      .update({
        xp: newXP,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    const { data: lvlAfter } = await supabase
      .from('user_xp')
      .select('level')
      .eq('user_id', userId)
      .single();

    // Save purchase
    purchases.push(itemId);
    allPurchases[userId] = purchases;
    savePurchases(allPurchases);

    // Recalculate hint balance after purchase
    const hintPurchasesAfter = purchases.filter(p => p === 'hint_pack_3' || p === 'hint_pack_10');
    let totalHintsAfter = 0;
    for (const hp of hintPurchasesAfter) totalHintsAfter += hp === 'hint_pack_3' ? 3 : 10;
    const usedHintsAfter = purchases.filter(p => p === 'hint_used').length;
    const hintBalanceAfter = Math.max(0, totalHintsAfter - usedHintsAfter);

    return res.json({
      success: true,
      item: item.name,
      xp_remaining: newXP,
      level: lvlAfter?.level || userLevel,
      hintBalance: hintBalanceAfter,
      purchases,
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── GET /api/gamification/inventory — Get user's owned items ───
router.get('/inventory', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const allPurchases = loadPurchases();
    const purchases = allPurchases[userId] || [];

    // Group owned non-consumable items
    const ownedItems = SHOP_ITEMS.filter(item => {
      if (item.category === 'consumable') return false;
      return purchases.includes(item.id);
    });

    // Hint balance
    const hintPurchases = purchases.filter(p => p === 'hint_pack_3' || p === 'hint_pack_10');
    let totalHints = 0;
    for (const hp of hintPurchases) totalHints += hp === 'hint_pack_3' ? 3 : 10;
    const usedHints = purchases.filter(p => p === 'hint_used').length;
    const hintBalance = Math.max(0, totalHints - usedHints);

    // Active avatar
    const activeAvatar = purchases.find(p => p.startsWith('active_avatar:'));
    const activeAvatarId = activeAvatar ? activeAvatar.split(':')[1] : null;

    // Active title
    const activeTitle = purchases.find(p => p.startsWith('active_title:'));
    const activeTitleId = activeTitle ? activeTitle.split(':')[1] : null;

    return res.json({ ownedItems, hintBalance, activeAvatarId, activeTitleId });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── POST /api/gamification/equip — Equip avatar or title ───
router.post('/equip', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { itemId } = req.body;

    const item = SHOP_ITEMS.find(i => i.id === itemId);
    if (!item) return res.status(404).json({ error: 'Article introuvable' });

    const allPurchases = loadPurchases();
    const purchases = allPurchases[userId] || [];

    if (!purchases.includes(itemId)) {
      return res.status(400).json({ error: 'Vous ne possédez pas cet article' });
    }

    // Remove old active of same type
    const prefix = item.category === 'avatar' ? 'active_avatar:' : 'active_title:';
    const filtered = purchases.filter(p => !p.startsWith(prefix));
    filtered.push(`${prefix}${itemId}`);
    allPurchases[userId] = filtered;
    savePurchases(allPurchases);

    return res.json({ success: true, equipped: itemId });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── POST /api/gamification/use-hint — Consume one hint ───
router.post('/use-hint', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const allPurchases = loadPurchases();
    const purchases = allPurchases[userId] || [];

    // Calculate balance
    const hintPurchases = purchases.filter(p => p === 'hint_pack_3' || p === 'hint_pack_10');
    let totalHints = 0;
    for (const hp of hintPurchases) totalHints += hp === 'hint_pack_3' ? 3 : 10;
    const usedHints = purchases.filter(p => p === 'hint_used').length;
    const hintBalance = totalHints - usedHints;

    if (hintBalance <= 0) {
      return res.status(400).json({ error: 'Aucun indice disponible', hintBalance: 0 });
    }

    purchases.push('hint_used');
    allPurchases[userId] = purchases;
    savePurchases(allPurchases);

    return res.json({ success: true, hintBalance: hintBalance - 1 });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── POST /api/gamification/quiz-reward — Reward user after quiz completion ───
router.post('/quiz-reward', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const { quiz_key, score, total, time_spent_seconds } = req.body || {};

    const totalQ = Math.max(1, Number(total) || 1);
    const good = Math.max(0, Math.min(totalQ, Number(score) || 0));
    const accuracy = good / totalQ;
    const quizKey = String(quiz_key || 'quiz-generic').trim() || 'quiz-generic';
    const timeSpent = Math.max(0, Number(time_spent_seconds) || 0);

    const attemptsDb = loadQuizAttempts();
    const userEntries = Array.isArray(attemptsDb[userId]) ? attemptsDb[userId] : [];
    const previousCompletions = userEntries.filter((a) => a.quiz_key === quizKey).length;
    const replayScale = [1, 0.55, 0.3, 0.15, 0.1][Math.min(previousCompletions, 4)];

    const speedBonus = timeSpent > 0 && timeSpent <= 900 ? 0.1 : 0; // <=15 min
    const basePoints = Math.round((accuracy * 100) + (speedBonus * 100));
    const baseXP = Math.round(60 + (accuracy * 140) + (speedBonus * 40));
    const pointsEarned = Math.max(0, Math.round(basePoints * replayScale));
    let xpEarned = Math.max(1, Math.round(baseXP * replayScale));

    // Apply XP boost (money) if user owns at least one and hasn't consumed it yet.
    // Stored as purchases in purchases.json (no DB migration).
    try {
      const allPurchases = loadPurchases();
      const purchases = Array.isArray(allPurchases[userId]) ? allPurchases[userId] : [];
      const bought = purchases.filter((p) => p === 'xp_boost').length;
      const used = purchases.filter((p) => p === 'xp_boost_used').length;
      const balance = bought - used;

      if (balance > 0) {
        xpEarned = xpEarned * 2;
        purchases.push('xp_boost_used');
        allPurchases[userId] = purchases;
        savePurchases(allPurchases);
      }
    } catch (e) {
      // Non-blocking: scoring should still work even if purchases store fails.
      console.warn('Failed to apply XP boost:', e.message);
    }

    userEntries.push({
      quiz_key: quizKey,
      score: good,
      total: totalQ,
      accuracy,
      points_earned: pointsEarned,
      xp_earned: xpEarned,
      replay_multiplier: replayScale,
      time_spent_seconds: timeSpent,
      created_at: new Date().toISOString(),
    });
    attemptsDb[userId] = userEntries;
    saveQuizAttempts(attemptsDb);

    await awardXP(userId, xpEarned);

    const { data: userSessions } = await supabase
      .from('sessions')
      .select('progress,score')
      .eq('user_id', userId)
      .not('score', 'is', null);

    const sessionPoints = Array.isArray(userSessions)
      ? userSessions.reduce((acc, s) => {
          const earned = Number(s?.progress?.points?.earned);
          if (Number.isFinite(earned)) return acc + earned;
          return acc + Math.max(0, Math.min(100, Math.round((Number(s?.score) || 0) * 5)));
        }, 0)
      : 0;

    const quizPoints = userEntries.reduce((acc, q) => acc + (Number(q?.points_earned) || 0), 0);
    const totalPoints = sessionPoints + quizPoints;
    const level = await setLevelFromPoints(userId, totalPoints);
    await checkAndAwardBadges(userId);

    return res.json({
      ok: true,
      quiz_key: quizKey,
      score: good,
      total: totalQ,
      accuracy,
      points_earned: pointsEarned,
      xp_earned: xpEarned,
      replay_multiplier: replayScale,
      previous_completions: previousCompletions,
      total_points: totalPoints,
      level,
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── GET /api/gamification/quiz-attempts — Current user's quiz history ───
router.get('/quiz-attempts', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const attemptsDb = loadQuizAttempts();
    const attempts = Array.isArray(attemptsDb[userId]) ? attemptsDb[userId] : [];

    const summary = attempts.reduce((acc, entry) => {
      const key = String(entry?.quiz_key || '').trim();
      if (!key) return acc;
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});

    return res.json({ attempts, summary });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── Internal: Award XP and check badges (called by session conclude) ───
const awardXP = async (userId, points) => {
  try {
    const { data: current } = await supabase.from('user_xp').select('xp,level').eq('user_id', userId).single();
    if (!current) {
      await supabase.from('user_xp').insert([{ user_id: userId, xp: points, level: 1 }]);
    } else {
      const newXP = (current.xp || 0) + points;
      // XP is used as currency only; level is derived from trophies.
      await supabase.from('user_xp').update({ xp: newXP, updated_at: new Date().toISOString() }).eq('user_id', userId);
    }
  } catch (e) {
    console.warn('Failed to award XP:', e.message);
  }
};

const setLevelFromPoints = async (userId, _ignored) => {
  try {
    const { trophies } = await computeTrophiesForUser(userId);
    const level = levelFromTrophies(trophies);

    const { data: current } = await supabase
      .from('user_xp')
      .select('xp,level')
      .eq('user_id', userId)
      .single();

    if (!current) {
      await supabase
        .from('user_xp')
        .insert([{ user_id: userId, xp: 0, level }]);
      return level;
    }

    await supabase
      .from('user_xp')
      .update({ level, updated_at: new Date().toISOString() })
      .eq('user_id', userId);

    return level;
  } catch (e) {
    console.warn('Failed to set level from points:', e.message);
    return null;
  }
};

const checkAndAwardBadges = async (userId) => {
  try {
    // Count completed sessions
    const { count: completedCount } = await supabase
      .from('sessions')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .not('score', 'is', null);

    // Count correct diagnoses (score >= 14)
    const { count: correctCount } = await supabase
      .from('sessions')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .gte('score', 14);

    // Get all badges and user's existing badges
    const { data: allBadges } = await supabase.from('badges').select('*');
    const { data: userBadges } = await supabase.from('user_badges').select('badge_id').eq('user_id', userId);
    const earnedIds = new Set((userBadges || []).map(b => b.badge_id));

    const newBadges = [];
    for (const badge of (allBadges || [])) {
      if (earnedIds.has(badge.id)) continue;

      let earned = false;
      if (badge.condition_type === 'cases_completed' && completedCount >= badge.condition_value) earned = true;
      if (badge.condition_type === 'correct_diagnoses' && correctCount >= badge.condition_value) earned = true;

      if (earned) {
        newBadges.push({ user_id: userId, badge_id: badge.id });
      }
    }

    if (newBadges.length > 0) {
      await supabase.from('user_badges').insert(newBadges);
    }

    return newBadges.length;
  } catch (e) {
    console.warn('Badge check failed:', e.message);
    return 0;
  }
};

// ─── GET /api/gamification/streak — Série de jours consécutifs ───────────────
router.get('/streak', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;

    // Récupère les jours distincts où l'utilisateur a terminé une session (score non null)
    const { data: rows, error } = await supabase
      .from('sessions')
      .select('created_at')
      .eq('user_id', userId)
      .not('score', 'is', null)
      .order('created_at', { ascending: false })
      .limit(365);

    if (error) return res.status(500).json({ error: error.message });

    // Extraire les dates uniques (YYYY-MM-DD)
    const activeDays = new Set(
      (rows || []).map((r) => new Date(r.created_at).toISOString().slice(0, 10))
    );

    // Calculer les jours consécutifs à partir d'aujourd'hui ou d'hier
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const toKey = (d) => d.toISOString().slice(0, 10);

    let streak = 0;
    const cursor = new Date(today);

    // Si pas actif aujourd'hui, commencer depuis hier
    if (!activeDays.has(toKey(cursor))) {
      cursor.setDate(cursor.getDate() - 1);
    }

    while (activeDays.has(toKey(cursor))) {
      streak += 1;
      cursor.setDate(cursor.getDate() - 1);
    }

    return res.json({ streak, lastActiveDate: streak > 0 ? toKey(new Date(today)) : null });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
module.exports.awardXP = awardXP;
module.exports.checkAndAwardBadges = checkAndAwardBadges;
module.exports.setLevelFromPoints = setLevelFromPoints;
