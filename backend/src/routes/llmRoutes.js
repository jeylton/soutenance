const express = require('express');
const router = express.Router();
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const supabase = require('../config/supabase');
const { generateResponse, generatePatientResponse, generateCase, generateCourse, generateQuizFromCase } = require('../services/llmService');
const { resolveAvatarProfile } = require('../services/avatarVoiceProfile');

const PUBLISHED_QUIZZES_FILE = path.join(__dirname, '../../data/published_quizzes.json');

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

const normalizeDiagnosisKey = (value) =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

function loadPublishedQuizzes() {
  try {
    return JSON.parse(fs.readFileSync(PUBLISHED_QUIZZES_FILE, 'utf8'));
  } catch (_) {
    return [];
  }
}

function savePublishedQuizzes(rows) {
  fs.mkdirSync(path.dirname(PUBLISHED_QUIZZES_FILE), { recursive: true });
  fs.writeFileSync(PUBLISHED_QUIZZES_FILE, JSON.stringify(rows, null, 2));
}

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

// Patient endpoint (uses new intelligent system)
router.post('/patient', async (req, res) => {
  const { case_id, question } = req.body;
  if (!case_id) {
    return res.status(400).json({ error: 'case_id required' });
  }
  try {
    const { data: caseRow, error: caseError } = await supabase.from('cases').select('*').eq('id', case_id).single();
    if (caseError) {
      return res.status(500).json({ error: caseError.message });
    }
    const response = await generatePatientResponse(caseRow, question);
    return res.json({ reply: response });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ElevenLabs voice endpoint for patient speech
router.post('/patient-voice', async (req, res) => {
  const { case_id, text, voice_id } = req.body || {};
  if (!case_id || !text) {
    return res.status(400).json({ error: 'case_id and text required' });
  }

  const apiKey = (process.env.ELEVENLABS_API_KEY || '').trim();
  if (!apiKey) {
    return res.status(501).json({ error: 'ELEVENLABS_API_KEY not configured' });
  }

  try {
    const { data: caseRow, error: caseError } = await supabase
      .from('cases')
      .select('avatar,medical_history')
      .eq('id', case_id)
      .single();

    if (caseError) {
      return res.status(500).json({ error: caseError.message });
    }

    const history = caseRow?.medical_history || {};
    const profile = resolveAvatarProfile({
      avatar: caseRow?.avatar,
      age: history?.age,
      gender: history?.gender,
    });

    const selectedVoiceId =
      (voice_id || '').toString().trim() ||
      (profile?.voiceId || '').toString().trim() ||
      (history?.eleven_voice_id || '').toString().trim();

    if (!selectedVoiceId) {
      return res.status(422).json({ error: 'No ElevenLabs voice available for this patient' });
    }

    const elevenRes = await axios.post(
      `https://api.elevenlabs.io/v1/text-to-speech/${selectedVoiceId}`,
      {
        text,
        model_id: process.env.ELEVENLABS_MODEL_ID || 'eleven_multilingual_v2',
        voice_settings: {
          stability: 0.4,
          similarity_boost: 0.8,
          style: 0.15,
          use_speaker_boost: true,
        },
      },
      {
        responseType: 'arraybuffer',
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          Accept: 'audio/mpeg',
        },
      },
    );

    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('x-dica-voice-id', selectedVoiceId);
    return res.send(Buffer.from(elevenRes.data));
  } catch (e) {
    const details = e?.response?.data
      ? Buffer.from(e.response.data).toString('utf8').slice(0, 240)
      : e.message;
    return res.status(500).json({ error: `ElevenLabs synthesis failed: ${details}` });
  }
});

// Tutor endpoint
router.post('/tutor', async (req, res) => {
  const { session_id } = req.body;
  if (!session_id) {
    return res.status(400).json({ error: 'session_id required' });
  }
  try {
    const { data: sessionRow, error: sErr } = await supabase.from('sessions').select('*').eq('id', session_id).single();
    if (sErr) {
      return res.status(500).json({ error: sErr.message });
    }
    const { data: caseRow, error: cErr } = await supabase.from('cases').select('*').eq('id', sessionRow.case_id).single();
    if (cErr) {
      return res.status(500).json({ error: cErr.message });
    }
    const base = caseRow.prompt_tuteur || '';
    const logic = caseRow.logic_medicale || '';
    const progress = sessionRow.progress ? JSON.stringify(sessionRow.progress) : '{}';
    const prompt = [
      base,
      'Tu es un tuteur pedagogique. Analyse le raisonnement clinique.',
      'Logique medicale attendue: ' + logic,
      'Actions de letudiant: ' + progress,
      'Fournis un feedback structure: points forts, erreurs, recommandations.',
    ].join('\n');
    const response = await generateResponse(prompt);
    const { error: updErr } = await supabase.from('sessions').update({ feedback: response }).eq('id', session_id);
    if (updErr) console.warn('Failed updating feedback:', updErr.message);
    return res.json({ feedback: response });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── AI Case Generation ───
router.post('/generate-case', async (req, res) => {
  const { specialty_name, specialty_id, difficulty, excluded_diagnoses } = req.body;
  if (!specialty_name || !difficulty) {
    return res.status(400).json({ error: 'specialty_name and difficulty required' });
  }
  try {
    let resolvedSpecialtyId = specialty_id || null;

    if (!resolvedSpecialtyId) {
      const { data: specByName } = await supabase
        .from('specialties')
        .select('id,name')
        .ilike('name', specialty_name)
        .limit(1)
        .maybeSingle();
      resolvedSpecialtyId = specByName?.id || null;
    }

    let excludedDiagnoses = [];
    if (resolvedSpecialtyId) {
      const { data: existingCases } = await supabase
        .from('cases')
        .select('disease_id,logic_medicale')
        .eq('specialty_id', resolvedSpecialtyId);

      const unique = new Map();
      for (const row of (existingCases || [])) {
        const raw = (row?.disease_id || row?.logic_medicale || '').toString().trim();
        if (!raw) continue;
        const key = normalizeDiagnosisKey(raw);
        if (key && !unique.has(key)) unique.set(key, raw);
      }
      excludedDiagnoses = Array.from(unique.values());
    }

    if (Array.isArray(excluded_diagnoses) && excluded_diagnoses.length > 0) {
      const merged = new Map();
      for (const d of [...excludedDiagnoses, ...excluded_diagnoses]) {
        const raw = String(d || '').trim();
        if (!raw) continue;
        const key = normalizeDiagnosisKey(raw);
        if (key && !merged.has(key)) merged.set(key, raw);
      }
      excludedDiagnoses = Array.from(merged.values());
    }

    let caseData = null;
    let lastDiagnosisKey = '';

    const candidatePoolByDifficulty = {
      1: [
        'Hypertension artérielle essentielle',
        'Asthme aigu simple',
        'Otite moyenne aiguë',
        'Vaginose bactérienne',
        'Migraine sans aura',
        'Infection urinaire basse',
      ],
      2: [
        'Insuffisance cardiaque gauche décompensée',
        'Pneumonie communautaire lobaire',
        'Gastro-entérite aiguë simple',
        'Dysménorrhée primaire',
        'Vertige positionnel paroxystique bénin',
        'Colique néphrétique simple',
      ],
      3: [
        'Syndrome coronarien aigu sans sus-décalage ST',
        'Exacerbation aiguë de BPCO',
        'Bronchiolite modérée',
        'Maladie inflammatoire pelvienne',
        'Syndrome méningé viral',
        'Pyélonéphrite aiguë',
      ],
      4: [
        'Fibrillation auriculaire rapide',
        'Embolie pulmonaire intermédiaire',
        'Grossesse extra-utérine non rompue',
        'AVC ischémique sylvien',
        'Insuffisance rénale aiguë fonctionnelle',
        'Méningite bactérienne pédiatrique',
      ],
      5: [
        'Dissection aortique de type B',
        'Tamponnade péricardique',
        'Pneumothorax compressif',
        'SDRA débutant',
        'Pré-éclampsie sévère',
        'Hémorragie sous-arachnoïdienne',
        'Encéphalite herpétique',
        'Hyperkaliémie menaçante sur insuffisance rénale',
      ],
    };
    const diff = Math.min(5, Math.max(1, Number(difficulty) || 1));
    const difficultyPool = candidatePoolByDifficulty[diff] || candidatePoolByDifficulty[3];
    const filteredDifficultyPool = difficultyPool.filter(
      (d) => !excludedDiagnoses.some((e) => normalizeDiagnosisKey(e) === normalizeDiagnosisKey(d)),
    );

    for (let attempt = 1; attempt <= 4; attempt += 1) {
      const forcedDiagnosis = filteredDifficultyPool.length > 0
        ? filteredDifficultyPool[(attempt - 1) % filteredDifficultyPool.length]
        : '';

      caseData = await generateCase(specialty_name, difficulty, {
        excludedDiagnoses,
        forcedDiagnosis,
        generationSeed: `${Date.now()}-${Math.random()}-a${attempt}`,
      });

      lastDiagnosisKey = normalizeDiagnosisKey(caseData?.diagnosis || caseData?.disease_id || '');
      if (!lastDiagnosisKey) break;

      const alreadyUsed = excludedDiagnoses.some((d) => normalizeDiagnosisKey(d) === lastDiagnosisKey);
      if (!alreadyUsed) break;
      if (attempt === 4) {
        return res.status(409).json({
          error: 'Impossible de générer une nouvelle maladie inédite pour cette spécialité. Toutes les options semblent déjà utilisées.',
          specialty_id: resolvedSpecialtyId,
        });
      }
    }

    return res.json({ case: caseData });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── AI Quiz Generation (disease-specific) ───
router.post('/generate-quiz', async (req, res) => {
  const { specialty_id, question_count, disease, case_id } = req.body || {};
  const specialtyId = Number(specialty_id);
  const caseId = Number(case_id);
  const questionCount = Number(question_count) || 30;
  const diseaseFilter = String(disease || '').trim();

  if (!Number.isFinite(specialtyId) || specialtyId <= 0) {
    return res.status(400).json({ error: 'specialty_id required' });
  }

  try {
    const { data: cases, error: casesError } = await supabase
      .from('cases')
      .select('id,patient_name,consultation_reason,initial_symptoms,medical_history,disease_id,logic_medicale,specialty_id,status')
      .eq('specialty_id', specialtyId)
      .in('status', ['active', 'draft'])
      .limit(200);

    if (casesError) {
      return res.status(500).json({ error: casesError.message });
    }

    const withDisease = (cases || []).filter((c) => (c?.disease_id || c?.logic_medicale));
    if (withDisease.length === 0) {
      return res.status(404).json({ error: 'Aucun cas avec maladie trouvée pour cette spécialité' });
    }

    const normalizeDisease = (value) =>
      String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();

    let candidates = withDisease;
    if (Number.isFinite(caseId) && caseId > 0) {
      candidates = withDisease.filter((c) => Number(c?.id) === caseId);
      if (candidates.length === 0) {
        return res.status(404).json({ error: 'Cas publié non trouvé pour cette spécialité' });
      }
    }

    if (diseaseFilter) {
      const wanted = normalizeDisease(diseaseFilter);
      candidates = candidates.filter((c) => {
        const dz = normalizeDisease(c?.disease_id || c?.logic_medicale || '');
        return dz === wanted;
      });
      if (candidates.length === 0) {
        return res.status(404).json({ error: 'Maladie non trouvée pour cette spécialité' });
      }
    }

    const picked = candidates[Math.floor(Math.random() * candidates.length)];
    const quiz = await generateQuizFromCase(picked, questionCount);

    const diseaseRaw = (picked.disease_id || picked.logic_medicale || '').toString();
    const diseaseKey = diseaseRaw
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');

    return res.json({
      quiz: {
        ...quiz,
        case_id: picked.id,
        specialty_id: specialtyId,
        disease: quiz?.disease || diseaseRaw,
        quiz_key: `sp-${specialtyId}-dz-${diseaseKey || picked.id}`,
      },
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── Quiz diseases by specialty ───
router.get('/quiz-diseases/:specialtyId', async (req, res) => {
  const specialtyId = Number(req.params.specialtyId);
  if (!Number.isFinite(specialtyId) || specialtyId <= 0) {
    return res.status(400).json({ error: 'specialtyId invalide' });
  }

  try {
    const { data: rows, error } = await supabase
      .from('cases')
      .select('disease_id,logic_medicale,status')
      .eq('specialty_id', specialtyId)
      .in('status', ['active', 'draft'])
      .limit(500);

    if (error) return res.status(500).json({ error: error.message });

    const normalizeDisease = (value) =>
      String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();

    const unique = new Map();
    for (const row of (rows || [])) {
      const raw = String(row?.disease_id || row?.logic_medicale || '').trim();
      if (!raw) continue;
      const key = normalizeDisease(raw);
      if (key && !unique.has(key)) unique.set(key, raw);
    }

    return res.json({ diseases: Array.from(unique.values()) });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── Quiz published cases by specialty ───
router.get('/quiz-cases/:specialtyId', async (req, res) => {
  const specialtyId = Number(req.params.specialtyId);
  if (!Number.isFinite(specialtyId) || specialtyId <= 0) {
    return res.status(400).json({ error: 'specialtyId invalide' });
  }

  try {
    const { data: rows, error } = await supabase
      .from('cases')
      .select('id,patient_name,consultation_reason,disease_id,logic_medicale,status')
      .eq('specialty_id', specialtyId)
      .eq('status', 'active')
      .order('id', { ascending: false })
      .limit(500);

    if (error) return res.status(500).json({ error: error.message });

    const cases = (rows || [])
      .map((row) => {
        const disease = String(row?.disease_id || row?.logic_medicale || '').trim();
        if (!disease) return null;
        const patient = String(row?.patient_name || '').trim();
        const reason = String(row?.consultation_reason || '').trim();
        const label = patient || reason || `Cas #${row.id}`;
        return {
          id: row.id,
          disease,
          label,
        };
      })
      .filter(Boolean);

    return res.json({ cases });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── Publish generated quiz (admin) ───
router.post('/publish-quiz', async (req, res) => {
  const payload = req.body || {};
  const quiz = payload.quiz || {};
  const requestedStatus = String(payload.status || quiz.status || 'published').trim().toLowerCase();
  const status = ['published', 'draft', 'archived'].includes(requestedStatus) ? requestedStatus : 'published';
  const questions = Array.isArray(quiz?.questions) ? quiz.questions : [];

  if (questions.length === 0) {
    return res.status(400).json({ error: 'Quiz vide, publication impossible' });
  }

  const published = loadPublishedQuizzes();
  const incomingQuizKey = String(quiz.quiz_key || '').trim();
  const shouldUpsert = status !== 'draft';
  const existingIdx = shouldUpsert
    ? published.findIndex((q) =>
      incomingQuizKey && String(q?.quiz_key || '').trim() === incomingQuizKey && String(q?.status || 'published') === status,
    )
    : -1;

  const id = existingIdx >= 0
    ? String(published[existingIdx]?.id || `quiz-${Date.now()}-${Math.floor(Math.random() * 10000)}`)
    : `quiz-${Date.now()}-${Math.floor(Math.random() * 10000)}`;

  const resolvedSpecialtyId = Number(quiz.specialty_id || payload.specialty_id || 0) || null;
  let specialtyName = String(quiz.specialty_name || payload.specialty_name || '').trim();
  if (!specialtyName && resolvedSpecialtyId) {
    const { data: specialtyRow } = await supabase
      .from('specialties')
      .select('name')
      .eq('id', resolvedSpecialtyId)
      .maybeSingle();
    specialtyName = String(specialtyRow?.name || '').trim();
  }

  const row = {
    id,
    title: String(quiz.title || 'Quiz').trim(),
    disease: String(quiz.disease || '').trim(),
    specialty_id: resolvedSpecialtyId,
    specialty_name: specialtyName || null,
    case_id: Number(quiz.case_id || payload.case_id || 0) || null,
    quiz_key: String(quiz.quiz_key || id),
    questions,
    status,
    ...(status === 'published' ? { published_at: new Date().toISOString() } : {}),
    updated_at: new Date().toISOString(),
  };

  if (existingIdx >= 0) {
    published[existingIdx] = {
      ...published[existingIdx],
      ...row,
      created_at: published[existingIdx]?.created_at || new Date().toISOString(),
    };
  } else {
    published.unshift({
      ...row,
      created_at: new Date().toISOString(),
    });
  }

  savePublishedQuizzes(published);
  return res.json({ quiz: row });
});

// ─── List published quizzes (mobile/player) ───
router.get('/published-quizzes', async (req, res) => {
  const status = String(req.query.status || 'published').trim().toLowerCase();
  const specialtyId = Number(req.query.specialty_id || 0);
  const rows = loadPublishedQuizzes();
  const withDefaults = (rows || []).map((q) => ({
    ...q,
    status: String(q?.status || 'published').toLowerCase(),
  }));

  const byStatus = status === 'all'
    ? withDefaults
    : withDefaults.filter((q) => q.status === status);

  const filtered = Number.isFinite(specialtyId) && specialtyId > 0
    ? byStatus.filter((q) => Number(q?.specialty_id) === specialtyId)
    : byStatus;

  return res.json({ quizzes: filtered });
});

// ─── Update published quiz metadata/status (admin) ───
router.patch('/published-quizzes/:id', async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) {
    return res.status(400).json({ error: 'id requis' });
  }

  const { status, title, disease } = req.body || {};
  const nextStatus = String(status || '').trim().toLowerCase();
  const allowedStatus = ['published', 'archived', 'draft'];
  if (nextStatus && !allowedStatus.includes(nextStatus)) {
    return res.status(400).json({ error: 'status invalide' });
  }

  const rows = loadPublishedQuizzes();
  const idx = rows.findIndex((q) => String(q?.id || '') === id);
  if (idx === -1) {
    return res.status(404).json({ error: 'quiz introuvable' });
  }

  const updated = {
    ...rows[idx],
    ...(typeof title === 'string' && title.trim() ? { title: title.trim() } : {}),
    ...(typeof disease === 'string' && disease.trim() ? { disease: disease.trim() } : {}),
    ...(nextStatus ? { status: nextStatus } : {}),
    updated_at: new Date().toISOString(),
  };

  rows[idx] = updated;
  savePublishedQuizzes(rows);
  return res.json({ quiz: updated });
});

// ─── Delete published quiz (admin) ───
router.delete('/published-quizzes/:id', async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) {
    return res.status(400).json({ error: 'id requis' });
  }

  const rows = loadPublishedQuizzes();
  const idx = rows.findIndex((q) => String(q?.id || '') === id);
  if (idx === -1) {
    return res.status(404).json({ error: 'quiz introuvable' });
  }

  const [removed] = rows.splice(idx, 1);
  savePublishedQuizzes(rows);
  return res.json({ deleted: true, quiz: removed });
});

// ─── AI Course Generation ───
router.post('/generate-course', async (req, res) => {
  const { case_id } = req.body;
  if (!case_id) {
    return res.status(400).json({ error: 'case_id required' });
  }
  try {
    // Fetch case with exams
    const { data: caseRow, error: caseError } = await supabase.from('cases').select('*').eq('id', case_id).single();
    if (caseError) {
      return res.status(500).json({ error: caseError.message });
    }
    const { data: exams } = await supabase.from('case_exams').select('name,result').eq('case_id', case_id);
    caseRow.case_exams = exams || [];
    const courseData = await generateCourse(caseRow);

    const svtValidation = validateSvtCourseContent(courseData?.content || '');
    if (!svtValidation.ok) {
      return res.status(400).json({
        error: 'Le cours IA ne respecte pas le format SVT obligatoire (13 sections)',
        missing_sections: svtValidation.missing,
      });
    }

    return res.json({ course: courseData });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── AI Hint for clinical case ───
router.post('/hint', async (req, res) => {
  const { case_id, hint_type } = req.body;
  if (!case_id) {
    return res.status(400).json({ error: 'case_id required' });
  }
  try {
    const { data: caseRow, error: caseError } = await supabase.from('cases').select('*').eq('id', case_id).single();
    if (caseError) return res.status(500).json({ error: caseError.message });

    const mh = caseRow.medical_history || {};
    const type = (hint_type || 'general').toString().toLowerCase();
    const guidanceByType = {
      exam: `Donne un indice orienté vers un examen complémentaire utile sans citer le diagnostic.\n- Mentionne au plus 2 examens pertinents.`,
      symptom: `Donne un indice orienté vers un symptôme/signe clinique important à explorer au lit du patient.`,
      general: `Donne un indice de raisonnement global (interrogatoire, examen clinique, physiopathologie).`,
    };

    const prompt = `Tu es un tuteur médical bienveillant. L'étudiant travaille sur un cas clinique et demande un indice.

Cas: ${caseRow.consultation_reason || caseRow.patient_name}
Symptômes initiaux: ${caseRow.initial_symptoms || ''}
Spécialité: ${mh.specialty || ''}
Difficulté: ${caseRow.difficulty || 1}/3
Type d'indice demandé: ${type}

${guidanceByType[type] || guidanceByType.general}

Donne UN SEUL indice concis (2-3 phrases max) qui aide l'étudiant à mieux orienter son raisonnement clinique SANS révéler le diagnostic directement. L'indice peut suggérer:
- Un axe d'interrogatoire à explorer
- Un signe clinique à rechercher
- Une piste de réflexion sur la physiopathologie

Réponds UNIQUEMENT avec l'indice, sans introduction ni conclusion.`;

    const hint = await generateResponse(prompt);
    return res.json({ hint });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
