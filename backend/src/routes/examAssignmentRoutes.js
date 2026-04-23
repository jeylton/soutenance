const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { authenticate, requireAdmin } = require('../middleware/auth');

// ─── GET /api/exam-assignments — List all exam assignments ───
router.get('/', authenticate, async (req, res) => {
  try {
    let query = supabase
      .from('exam_assignments')
      .select('*,cases(patient_name,consultation_reason)')
      .order('created_at', { ascending: false });

    // Students: filter by their group_name if they have one
    if (req.user.role === 'student') {
      const { data: userRow } = await supabase.from('users').select('group_name').eq('id', req.user.id).single();
      if (userRow && userRow.group_name) {
        // Show assignments matching their group OR assignments without a group (global)
        query = query.or(`group_name.eq.${userRow.group_name},group_name.is.null`);
      }
    }

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ assignments: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── POST /api/exam-assignments — Create an exam assignment (teacher/admin) ───
router.post('/', authenticate, requireAdmin, async (req, res) => {
  const { case_id, time_limit, due_date, group_name } = req.body;
  if (!case_id) return res.status(400).json({ error: 'case_id required' });
  try {
    const { data, error } = await supabase
      .from('exam_assignments')
      .insert([{
        case_id,
        assigned_by: req.user.id,
        time_limit: time_limit || null,
        due_date: due_date || null,
        group_name: group_name || null,
      }])
      .select('id')
      .single();
    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ id: data.id });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── DELETE /api/exam-assignments/:id ───
router.delete('/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const { error } = await supabase.from('exam_assignments').delete().eq('id', req.params.id);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
