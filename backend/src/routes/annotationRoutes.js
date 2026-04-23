const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// ─── GET /api/annotations/:sessionId — Get annotations for a session ───
router.get('/:sessionId', authenticate, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('session_annotations')
      .select('id,content,created_at,author_id,users!session_annotations_author_id_fkey(full_name)')
      .eq('session_id', req.params.sessionId)
      .order('created_at', { ascending: true });
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ annotations: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── POST /api/annotations/:sessionId — Add an annotation ───
router.post('/:sessionId', authenticate, async (req, res) => {
  const { content } = req.body;
  if (!content) return res.status(400).json({ error: 'content required' });
  try {
    const { data, error } = await supabase
      .from('session_annotations')
      .insert([{ session_id: req.params.sessionId, author_id: req.user.id, content }])
      .select('id,content,created_at')
      .single();
    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ annotation: data });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── DELETE /api/annotations/:sessionId/:annotationId ───
router.delete('/:sessionId/:annotationId', authenticate, async (req, res) => {
  try {
    const { error } = await supabase
      .from('session_annotations')
      .delete()
      .eq('id', req.params.annotationId)
      .eq('author_id', req.user.id);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
