const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

const sanitizeExamResultRaw = (value) => {
  if (value == null) return '';
  let text = String(value).replace(/\r/g, '').trim();
  if (!text) return '';
  text = text
    .split('\n')
    .filter((line) => !/^\s*(interpr[eé]tation|interpretation|conclusion|impression|diagnostic probable|orientation diagnostique)\s*[:\-]/i.test(line))
    .join('\n')
    .trim();
  return text.replace(/\s*(compatible avec|en faveur de|sugg[eè]re|[eé]voque|oriente vers)\b.*$/i, '').trim();
};

router.get('/', async (_req, res) => {
  try {
    const { data, error } = await supabase
      .from('cases')
      .select('*')
      .order('updated_at', { ascending: false });
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ cases: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const { data, error } = await supabase
      .from('cases')
      .select('*,case_exams(id,name,result)')
      .eq('id', id)
      .single();
    if (error) {
      return res.status(404).json({ error: 'Case not found' });
    }
    // Inject is_relevant from medical_history into case_exams
    if (data.case_exams) {
      data.case_exams = data.case_exams.map(e => ({
        ...e,
        result: sanitizeExamResultRaw(e.result),
        is_relevant: data.medical_history?.exam_relevance?.[e.name] !== undefined
          ? data.medical_history.exam_relevance[e.name] : true,
      }));
    }
    return res.json({ case: data });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.post('/', async (req, res) => {
  const {
    avatar,
    patient_id,
    patient_name,
    consultation_reason,
    initial_symptoms,
    medical_history,
    prompt_patient,
    prompt_tuteur,
    exams, // [{ name, result, is_relevant }]
    logic_medicale,
    difficulty, // 1..5
    disease_id,
    specialty_id,
  } = req.body;

  if (!patient_name || !consultation_reason) {
    return res.status(400).json({ error: 'patient_name and consultation_reason are required' });
  }

  try {
    // Build exam_relevance map and store in medical_history
    const examRelevance = {};
    if (Array.isArray(exams)) {
      exams.filter(e => e && e.name).forEach(e => {
        examRelevance[e.name] = e.is_relevant !== undefined ? e.is_relevant : true;
      });
    }
    const historyWithRelevance = { ...(medical_history || {}), exam_relevance: examRelevance };

    const { data: caseInsert, error: caseError } = await supabase
      .from('cases')
      .insert([
        {
          avatar: avatar || null,
          patient_id: patient_id || null,
          patient_name,
          consultation_reason,
          initial_symptoms: initial_symptoms || null,
          medical_history: historyWithRelevance,
          prompt_patient: prompt_patient || null,
          prompt_tuteur: prompt_tuteur || null,
          logic_medicale: logic_medicale || null,
          difficulty: difficulty || 1,
          disease_id: disease_id || null,
          specialty_id: specialty_id || null,
          status: 'draft',
        },
      ])
      .select('id')
      .single();

    if (caseError) {
      return res.status(500).json({ error: caseError.message });
    }

    const caseId = caseInsert.id;

    if (Array.isArray(exams) && exams.length > 0) {
      const examRows = exams
        .filter((e) => e && e.name)
        .map((e) => ({
          case_id: caseId,
          name: e.name,
          result: e.result || '',
          is_relevant: e.is_relevant !== false,
        }));
      if (examRows.length > 0) {
        const { error: examError } = await supabase.from('case_exams').insert(examRows);
        if (examError) {
          console.warn('Exam insert error:', examError.message);
        }
      }
    }

    return res.status(201).json({ id: caseId });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.get('/:id/exams', async (req, res) => {
  const { id } = req.params;
  try {
    const { data, error } = await supabase.from('case_exams').select('name,result').eq('case_id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ exams: (data || []).map((e) => ({ ...e, result: sanitizeExamResultRaw(e.result) })) });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.patch('/:id/difficulty', async (req, res) => {
  const { id } = req.params;
  const { difficulty } = req.body;
  if (difficulty == null) {
    return res.status(400).json({ error: 'difficulty required' });
  }
  try {
    const { error } = await supabase.from('cases').update({ difficulty }).eq('id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.patch('/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status } = req.body; // draft | active | archived
  if (!status) {
    return res.status(400).json({ error: 'status required' });
  }
  try {
    const { error } = await supabase.from('cases').update({ status }).eq('id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// PUT update full case
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const {
    avatar, patient_id, patient_name, consultation_reason,
    initial_symptoms, medical_history, prompt_patient, prompt_tuteur,
    logic_medicale, difficulty, disease_id, exams, status, specialty_id
  } = req.body;

  try {
    const update = {};
    if (avatar != null) update.avatar = avatar;
    if (patient_id != null) update.patient_id = patient_id;
    if (patient_name != null) update.patient_name = patient_name;
    if (consultation_reason != null) update.consultation_reason = consultation_reason;
    if (initial_symptoms != null) update.initial_symptoms = initial_symptoms;
    if (medical_history != null) update.medical_history = medical_history;
    if (prompt_patient != null) update.prompt_patient = prompt_patient;
    if (prompt_tuteur != null) update.prompt_tuteur = prompt_tuteur;
    if (logic_medicale != null) update.logic_medicale = logic_medicale;
    if (difficulty != null) update.difficulty = difficulty;
    if (disease_id != null) update.disease_id = disease_id;
    if (specialty_id != null) update.specialty_id = specialty_id;
    if (status != null) update.status = status;
    update.updated_at = new Date().toISOString();

    const { error } = await supabase.from('cases').update(update).eq('id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }

    // Update exams if provided
    if (Array.isArray(exams)) {
      // Update exam_relevance in medical_history
      const examRelevance = {};
      exams.filter(e => e && e.name).forEach(e => {
        examRelevance[e.name] = e.is_relevant !== undefined ? e.is_relevant : true;
      });
      const { data: existingCase } = await supabase.from('cases').select('medical_history').eq('id', id).single();
      const updatedHistory = { ...(existingCase?.medical_history || {}), exam_relevance: examRelevance };
      await supabase.from('cases').update({ medical_history: updatedHistory }).eq('id', id);

      // Delete existing exams and re-insert
      await supabase.from('case_exams').delete().eq('case_id', id);
      if (exams.length > 0) {
        const examRows = exams.filter(e => e && e.name).map(e => ({
          case_id: Number(id), name: e.name, result: e.result || '',
          is_relevant: e.is_relevant !== false,
        }));
        if (examRows.length > 0) {
          await supabase.from('case_exams').insert(examRows);
        }
      }
    }

    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// DELETE case
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const { error } = await supabase.from('cases').delete().eq('id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
