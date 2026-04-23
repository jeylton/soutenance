const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

router.post('/seed', async (_req, res) => {
  try {
    const inserts = [];
    // specialties
    inserts.push(supabase.from('specialties').insert([{ name: 'Cardiologie' }, { name: 'Pédiatrie' }]));
    // clinics
    inserts.push(supabase.from('clinics').insert([{ name: 'Clinique A' }, { name: 'Clinique B' }]));
    // cases
    const { data: caseRow, error: caseErr } = await supabase
      .from('cases')
      .insert([
        {
          patient_id: 'PAT-001',
          patient_name: 'Jean Dupont',
          avatar: 'avatar1.png',
          consultation_reason: 'Fièvre, frissons, fatigue',
          initial_symptoms: 'Fièvre 39°C, frissons, fatigue',
          medical_history: { antecedents: { perso: ['HTA'], familiaux: { pere: ['Diabète'], mere: [] } }, allergies: [] },
          prompt_patient: 'Tu joues un patient avec fièvre depuis 2 jours.',
          prompt_tuteur: 'Analyse le raisonnement pour fièvre aiguë.',
          logic_medicale: 'Démarche diagnostique des syndromes fébriles.',
          difficulty: 2,
          disease_id: 'INFECTION_VIRALE',
          status: 'active',
        },
      ])
      .select('id')
      .single();
    if (caseErr) {
      return res.status(500).json({ error: caseErr.message });
    }
    // exams for case
    inserts.push(
      supabase.from('case_exams').insert([
        { case_id: caseRow.id, name: 'NFS', result: 'Hb 13 g/dL, Leuco 8k, Plaquettes 250k' },
        { case_id: caseRow.id, name: 'CRP', result: 'CRP 12 mg/L' },
      ])
    );
    // course
    inserts.push(
      supabase
        .from('courses')
        .insert([
          {
            title: 'Approche de la fièvre',
            content: 'Cours sur la démarche diagnostique devant une fièvre.',
            pdf_url: null,
            case_id: caseRow.id,
            status: 'published',
            specialty_id: null,
          },
        ])
    );
    // execute batched inserts
    await Promise.all(inserts);
    return res.json({ ok: true, case_id: caseRow.id });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
