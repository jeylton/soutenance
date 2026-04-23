const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { generateCourse } = require('../services/llmService');

const REQUIRED_SVT_SECTIONS = [
  '1. TITRE DU COURS :',
  '2. PROBLEMATIQUE SVT :',
  '3. OBJECTIFS D\'APPRENTISSAGE :',
  '4. PREREQUIS :',
  '5. VOCABULAIRE CLE :',
  '6. RAPPELS ANATOMIE ET PHYSIOLOGIE :',
  '7. MECANISME DE LA MALADIE (PHYSIOPATHOLOGIE) :',
  '8. CAUSES ET FACTEURS DE RISQUE :',
  '9. SIGNES CLINIQUES :',
  '10. EXAMENS ET INTERPRETATION GENERALE :',
  '11. PRINCIPES DE PRISE EN CHARGE (SANS RESOUDRE LE CAS) :',
  '12. PREVENTION ET SURVEILLANCE :',
  '13. ERREURS FREQUENTES :',
];

const normalizeText = (value) =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase();

const validateSvtCourseContent = (content) => {
  const normalized = normalizeText(content);
  const missing = [];
  let cursor = 0;

  for (const section of REQUIRED_SVT_SECTIONS) {
    const normalizedSection = normalizeText(section);
    const index = normalized.indexOf(normalizedSection, cursor);
    if (index === -1) {
      missing.push(section);
      continue;
    }
    cursor = index + normalizedSection.length;
  }

  return {
    ok: missing.length === 0,
    missing,
  };
};

router.get('/', async (_req, res) => {
  try {
    const { data, error } = await supabase
      .from('courses')
      .select('id,title,content,pdf_url,case_id,status,specialty_id,created_at');
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ courses: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.post('/', async (req, res) => {
  const { case_id } = req.body;
  if (!case_id) {
    return res.status(400).json({ error: 'case_id required for AI course generation' });
  }

  try {
    const { data: caseRow, error: caseError } = await supabase
      .from('cases')
      .select('*')
      .eq('id', case_id)
      .single();
    if (caseError || !caseRow) {
      return res.status(404).json({ error: 'Case not found for course generation' });
    }

    const { data: exams } = await supabase
      .from('case_exams')
      .select('name,result')
      .eq('case_id', case_id);
    caseRow.case_exams = exams || [];

    const aiCourse = await generateCourse(caseRow);
    const finalTitle = aiCourse?.title || `Cours: ${caseRow.consultation_reason || 'Cas clinique'}`;
    const finalContent = aiCourse?.content || '';
    const finalSpecialtyId = caseRow.specialty_id || null;
    const finalPdfUrl = Array.isArray(aiCourse?.references) && aiCourse.references.length > 0
      ? `REF::${JSON.stringify(aiCourse.references)}`
      : null;

    if (!finalTitle || !finalContent) {
      return res.status(400).json({ error: 'Unable to generate course content' });
    }

    const svtValidation = validateSvtCourseContent(finalContent);
    if (!svtValidation.ok) {
      return res.status(400).json({
        error: 'Le cours généré ne respecte pas le format SVT obligatoire (13 sections)',
        missing_sections: svtValidation.missing,
      });
    }

    const { data: existingCourse, error: existingCourseError } = await supabase
      .from('courses')
      .select('id')
      .eq('case_id', case_id)
      .limit(1)
      .maybeSingle();

    if (existingCourseError) {
      return res.status(500).json({ error: existingCourseError.message });
    }

    if (existingCourse?.id) {
      const { error: updateError } = await supabase
        .from('courses')
        .update({
          title: finalTitle,
          content: finalContent,
          pdf_url: finalPdfUrl,
          specialty_id: finalSpecialtyId,
          status: 'published',
        })
        .eq('id', existingCourse.id);

      if (updateError) {
        return res.status(500).json({ error: updateError.message });
      }

      return res.status(200).json({ id: existingCourse.id, updated: true });
    }

    const { data, error } = await supabase
      .from('courses')
      .insert([{ title: finalTitle, content: finalContent, pdf_url: finalPdfUrl, case_id: case_id || null, specialty_id: finalSpecialtyId, status: 'published' }])
      .select('id')
      .single();
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.status(201).json({ id: data.id });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.patch('/:id', async (req, res) => {
  const { id } = req.params;
  const { title, content, pdf_url, case_id, specialty_id, status } = req.body;
  try {
    if (case_id != null) {
      const { data: conflict, error: conflictError } = await supabase
        .from('courses')
        .select('id')
        .eq('case_id', case_id)
        .neq('id', id)
        .limit(1)
        .maybeSingle();

      if (conflictError) {
        return res.status(500).json({ error: conflictError.message });
      }
      if (conflict?.id) {
        return res.status(409).json({ error: 'Un cours existe déjà pour ce cas clinique' });
      }
    }

    if (content != null) {
      const svtValidation = validateSvtCourseContent(content);
      if (!svtValidation.ok) {
        return res.status(400).json({
          error: 'Le contenu ne respecte pas le format SVT obligatoire (13 sections)',
          missing_sections: svtValidation.missing,
        });
      }
    }

    const update = {};
    if (title != null) update.title = title;
    if (content != null) update.content = content;
    if (pdf_url != null) update.pdf_url = pdf_url;
    if (case_id != null) update.case_id = case_id;
    if (specialty_id != null) update.specialty_id = specialty_id;
    if (status != null) update.status = status;
    const { error } = await supabase.from('courses').update(update).eq('id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const { error } = await supabase.from('courses').delete().eq('id', id);
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
