const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, requireAdmin } = require('../middleware/auth');

// GET /api/settings — get settings (admin only)
router.get('/', authenticate, requireAdmin, async (req, res) => {
  try {
    const { data, error } = await supabase.from('app_settings').select('*');
    if (error) return res.status(500).json({ error: error.message });
    // Convert array to key→value map
    const settings = {};
    (data || []).forEach(row => { settings[row.key] = row.value; });
    return res.json({ settings });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// PUT /api/settings — save settings (admin only)
router.put('/', authenticate, requireAdmin, async (req, res) => {
  const entries = req.body; // { key: value, key: value, ... }
  try {
    for (const [key, value] of Object.entries(entries)) {
      await supabase
        .from('app_settings')
        .upsert({ key, value: String(value), updated_at: new Date().toISOString() }, { onConflict: 'key' });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
