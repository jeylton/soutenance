const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const fs = require('fs');
const path = require('path');

const PURCHASES_FILE = path.join(__dirname, '../../data/purchases.json');
function loadPurchases() {
  try { return JSON.parse(fs.readFileSync(PURCHASES_FILE, 'utf8')); }
  catch { return {}; }
}

router.get('/', async (req, res) => {
  const { status } = req.query; // etudiant | medecin | interne | autre
  try {
    let query = supabase.from('users').select('id,email,full_name,profile_type,origin,created_at').eq('origin', 'mobile');
    if (status) {
      query = query.eq('profile_type', status);
    }
    const { data, error } = await query;
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    // Enrich with active avatar from purchases
    const purchases = loadPurchases();
    const users = (data || []).map(u => {
      const userPurchases = purchases[u.id] || [];
      const activeAvatar = userPurchases.find(p => p.startsWith('active_avatar:'));
      return { ...u, avatar_id: activeAvatar ? activeAvatar.split(':')[1] : null };
    });
    return res.json({ users });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
