const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// GET /api/chat/:sessionId — get chat history for a session
router.get('/:sessionId', authenticate, async (req, res) => {
  const { sessionId } = req.params;
  try {
    const { data, error } = await supabase
      .from('chat_messages')
      .select('id,role,content,created_at')
      .eq('session_id', sessionId)
      .order('created_at', { ascending: true });
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ messages: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// POST /api/chat/:sessionId — save a message
router.post('/:sessionId', authenticate, async (req, res) => {
  const { sessionId } = req.params;
  const { role, content } = req.body;
  if (!role || !content) return res.status(400).json({ error: 'role and content required' });
  try {
    const { data, error } = await supabase
      .from('chat_messages')
      .insert([{ session_id: sessionId, role, content }])
      .select('id,role,content,created_at')
      .single();
    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ message: data });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
