const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// GET /api/notifications — Get user notifications
router.get('/', authenticate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', req.user.id)
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ notifications: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// PATCH /api/notifications/:id/read — Mark as read
router.patch('/:id/read', authenticate, async (req, res) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ read: true })
      .eq('id', req.params.id)
      .eq('user_id', req.user.id);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// PATCH /api/notifications/read-all — Mark all as read
router.patch('/read-all', authenticate, async (req, res) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ read: true })
      .eq('user_id', req.user.id)
      .eq('read', false);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// Internal: Create a notification
const createNotification = async (userId, title, body, type) => {
  try {
    await supabase.from('notifications').insert([{ user_id: userId, title, body, type }]);
  } catch (e) {
    console.warn('Notification creation failed:', e.message);
  }
};

module.exports = router;
module.exports.createNotification = createNotification;
