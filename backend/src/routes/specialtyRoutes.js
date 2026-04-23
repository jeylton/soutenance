const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

// GET all specialties
router.get('/', async (_req, res) => {
  try {
    const { data, error } = await supabase.from('specialties').select('id,name').order('name');
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ specialties: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// POST create specialty
router.post('/', async (req, res) => {
  const { name } = req.body;
  if (!name) {
    return res.status(400).json({ error: 'name required' });
  }
  try {
    const { data, error } = await supabase
      .from('specialties')
      .insert([{ name }])
      .select('id,name')
      .single();
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.status(201).json(data);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// DELETE specialty
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const { error } = await supabase.from('specialties').delete().eq('id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
