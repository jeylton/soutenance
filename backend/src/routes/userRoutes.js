const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

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
    // Enrich with active avatar from Supabase purchases store
    const userIds = (data || []).map(u => String(u.id));
    let purchasesByUser = {};
    if (userIds.length > 0) {
      const { data: storeRows } = await supabase.from('user_purchases_store').select('user_id,purchases').in('user_id', userIds);
      for (const row of (storeRows || [])) {
        purchasesByUser[String(row.user_id)] = Array.isArray(row.purchases) ? row.purchases : [];
      }
    }
    const users = (data || []).map(u => {
      const userPurchases = purchasesByUser[String(u.id)] || [];
      const activeAvatar = userPurchases.find(p => p.startsWith('active_avatar:'));
      return { ...u, avatar_id: activeAvatar ? activeAvatar.split(':')[1] : null };
    });
    return res.json({ users });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
