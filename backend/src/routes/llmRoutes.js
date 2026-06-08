const express = require('express');
const router = express.Router();
const axios = require('axios');
const supabase = require('../config/supabase');
const { generateResponse, generatePatientResponse, generateCase, generateCourse, generateQuizFromCase } = require('../services/llmService');
const { resolveAvatarProfile, GOOGLE_TTS_PROFILES } = require('../services/avatarVoiceProfile');

// ─── Published quizzes — Supabase (persistent across Render restarts) ───
async function loadPublishedQuizzes() {
  try {
    const { data } = await supabase.from('published_quizzes').select('*').order('created_at', { ascending: false });
    return data || [];
  } catch { return []; }
}

async function upsertQuiz(row) {
  const { error } = await supabase.from('published_quizzes').upsert(row, { onConflict: 'id' });
  if (error) throw error;
}

async function updateQuizById(id, updates) {
  const { error } = await supabase.from('published_quizzes').update(updates).eq('id', id);
  if (error) throw error;
}

async function deleteQuizById(id) {
  const { error } = await supabase.from('published_quizzes').delete().eq('id', id);
  if (error) throw error;
}

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

function sendLlmError(res, err) {
  const message = String(err?.message || 'Unknown error');
  if (message.toLowerCase().includes('required but unavailable')) {
    const hint = process.env.GROQ_API_KEY
      ? 'Vérifiez que GROQ_API_KEY est valide sur console.groq.com et que le modèle GROQ_MODEL existe.'
      : 'Aucune GROQ_API_KEY trouvée dans .env. Ajoutez-la sur console.groq.com (plan gratuit disponible).';
    return res.status(503).json({ error: `${message}. ${hint}` });
  }
  return res.status(500).json({ error: message });
}

// GET /api/llm/health — teste la connectivité LLM
router.get('/health', async (req, res) => {
  const groqKey = String(process.env.GROQ_API_KEY || '').trim();
  const llamaModel = String(process.env.LLAMA_MODEL || '').trim();
  const result = {
    groq: { configured: !!groqKey, key_prefix: groqKey ? groqKey.slice(0, 8) + '...' : null },
    llama: { configured: !!llamaModel, model: llamaModel || null, url: process.env.LLAMA_BASE_URL || 'http://127.0.0.1:1234/v1' },
    provider: process.env.LLM_PROVIDER || 'auto',
  };
  try {
    const { generateResponse } = require('../services/llmService');
    const reply = await generateResponse('Réponds juste "ok"', 'Tu es un assistant. Réponds uniquement "ok".');
    result.test = reply ? 'ok' : 'failed';
  } catch (e) {
    result.test = 'error';
    result.error = e.message;
  }
  return res.json(result);
});

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
    return sendLlmError(res, e);
  }
});

// ─── Patient voice synthesis (ElevenLabs → Google Cloud TTS → 501) ──────────
router.post('/patient-voice', async (req, res) => {
  const { case_id, text, voice_id } = req.body || {};
  if (!case_id || !text) {
    return res.status(400).json({ error: 'case_id and text required' });
  }

  try {
    const { data: caseRow, error: caseError } = await supabase
      .from('cases')
      .select('avatar,medical_history')
      .eq('id', case_id)
      .single();

    if (caseError) return res.status(500).json({ error: caseError.message });

    const history = caseRow?.medical_history || {};
    const profile = resolveAvatarProfile({
      avatar: caseRow?.avatar,
      age: history?.age,
      gender: history?.gender,
    });

    // ── Tentative 1 : ElevenLabs ──────────────────────────────────────────────
    const elevenKey = (process.env.ELEVENLABS_API_KEY || '').trim();
    if (elevenKey) {
      const selectedVoiceId =
        (voice_id || '').toString().trim() ||
        (profile?.voiceId || '').toString().trim() ||
        (history?.eleven_voice_id || '').toString().trim();

      if (selectedVoiceId) {
        try {
          const elevenRes = await axios.post(
            `https://api.elevenlabs.io/v1/text-to-speech/${selectedVoiceId}`,
            {
              text,
              model_id: process.env.ELEVENLABS_MODEL_ID || 'eleven_multilingual_v2',
              voice_settings: { stability: 0.4, similarity_boost: 0.8, style: 0.15, use_speaker_boost: true },
            },
            {
              responseType: 'arraybuffer',
              headers: { 'xi-api-key': elevenKey, 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
              timeout: 15000,
            },
          );
          res.setHeader('Content-Type', 'audio/mpeg');
          res.setHeader('Cache-Control', 'no-store');
          res.setHeader('x-dica-tts-provider', 'elevenlabs');
          return res.send(Buffer.from(elevenRes.data));
        } catch (elevenErr) {
          console.warn('ElevenLabs unavailable, falling back to Google TTS:', elevenErr?.response?.status || elevenErr.message);
        }
      }
    }

    // ── Tentative 2 : VoiceRSS (gratuit, 350 req/jour, sans carte bancaire) ──
    const voiceRssKey = (process.env.VOICERSS_API_KEY || '').trim();
    if (voiceRssKey) {
      // Profil voix : rate (-10 à +10), voix selon genre
      const hint = profile?.hint || 'male_young';
      const voiceRssRate = {
        male_young:   0,
        female_young: 0,
        male_old:     -2,
        female_old:   -2,
        child_male:   3,
        child_female: 3,
      }[hint] ?? 0;

      // VoiceRSS French voices (fr-fr)
      const voiceRssVoice = {
        male_young:   'Axel',
        female_young: 'Bette',
        male_old:     'Axel',
        female_old:   'Nica',
        child_male:   'Axel',
        child_female: 'Bette',
      }[hint] ?? 'Bette';

      try {
        const params = new URLSearchParams({
          key: voiceRssKey,
          src: text,
          hl: 'fr-fr',
          v: voiceRssVoice,
          r: String(voiceRssRate),
          c: 'MP3',
          f: '44khz_16bit_stereo',
        });

        const voiceRes = await axios.get(
          `https://api.voicerss.org/?${params.toString()}`,
          { responseType: 'arraybuffer', timeout: 15000 },
        );

        // VoiceRSS renvoie du texte si erreur (pas un arraybuffer)
        const contentType = voiceRes.headers['content-type'] || '';
        if (!contentType.includes('audio')) {
          const errText = Buffer.from(voiceRes.data).toString('utf8');
          throw new Error(`VoiceRSS error: ${errText}`);
        }

        res.setHeader('Content-Type', 'audio/mpeg');
        res.setHeader('Cache-Control', 'no-store');
        res.setHeader('x-dica-tts-provider', 'voicerss');
        res.setHeader('x-dica-voice-name', voiceRssVoice);
        return res.send(Buffer.from(voiceRes.data));
      } catch (vErr) {
        console.warn('VoiceRSS failed:', vErr.message);
      }
    }

    // ── Tentative 3 : Google Cloud TTS (free tier 1M chars/mois) ─────────────
    const googleKey = (process.env.GOOGLE_TTS_API_KEY || '').trim();
    if (googleKey) {
      const gProfile = profile?.googleTts || GOOGLE_TTS_PROFILES.male_young;
      try {
        const googleRes = await axios.post(
          `https://texttospeech.googleapis.com/v1/text:synthesize?key=${googleKey}`,
          {
            input: { text },
            voice: { languageCode: 'fr-FR', name: gProfile.name },
            audioConfig: {
              audioEncoding: 'MP3',
              pitch: gProfile.pitch ?? 0,
              speakingRate: gProfile.speakingRate ?? 1.0,
              volumeGainDb: 1.0,
            },
          },
          { headers: { 'Content-Type': 'application/json' }, timeout: 15000 },
        );

        const audioContent = googleRes.data?.audioContent;
        if (!audioContent) throw new Error('Google TTS returned empty audio');

        res.setHeader('Content-Type', 'audio/mpeg');
        res.setHeader('Cache-Control', 'no-store');
        res.setHeader('x-dica-tts-provider', 'google');
        res.setHeader('x-dica-voice-name', gProfile.name);
        return res.send(Buffer.from(audioContent, 'base64'));
      } catch (googleErr) {
        console.warn('Google TTS failed:', googleErr?.response?.data?.error?.message || googleErr.message);
      }
    }

    // ── Aucun provider → fallback TTS natif côté mobile ──────────────────────
    return res.status(501).json({
      error: 'No TTS provider configured. Set VOICERSS_API_KEY in .env to enable cloud voices.',
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
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
    if (sErr) return res.status(500).json({ error: sErr.message });

    const { data: caseRow, error: cErr } = await supabase.from('cases').select('*').eq('id', sessionRow.case_id).single();
    if (cErr) return res.status(500).json({ error: cErr.message });

    const { data: examsRows } = await supabase.from('case_exams').select('name,is_relevant').eq('case_id', sessionRow.case_id);

    const progress = sessionRow.progress || {};
    const requestedExams = (progress.requested_exams || []).map(e => e?.name || e).filter(Boolean);
    const studentDiagnosis = progress.conclusion?.diagnosis || 'Non fourni';
    const studentPlan = progress.conclusion?.plan || 'Non fourni';
    const studentTreatment = progress.conclusion?.treatment || null;

    const expectedDiagnosis = caseRow.disease_id || caseRow.logic_medicale || 'Non renseigné';
    const expectedTreatment = (caseRow.medical_history?.treatment || [])
      .map(t => `${t.medication || ''} ${t.dosage || ''} ${t.frequency || ''} ${t.duration || ''}`.trim())
      .filter(Boolean)
      .join(', ') || 'Non renseigné';
    const treatmentNotes = caseRow.medical_history?.treatment_notes || '';

    const relevantExams = (examsRows || []).filter(e => e.is_relevant !== false).map(e => e.name);
    const decoyExams = (examsRows || []).filter(e => e.is_relevant === false).map(e => e.name);
    const orderedRelevant = requestedExams.filter(n => relevantExams.some(r => r.toLowerCase().includes(n.toLowerCase()) || n.toLowerCase().includes(r.toLowerCase())));
    const orderedDecoys = requestedExams.filter(n => decoyExams.some(r => r.toLowerCase().includes(n.toLowerCase()) || n.toLowerCase().includes(r.toLowerCase())));

    const tutorContext = caseRow.prompt_tuteur || '';

    const systemPrompt = `Tu es un tuteur médical expert. Tu fournis un retour pédagogique structuré, bienveillant mais rigoureux, à un étudiant en médecine qui vient de terminer une simulation clinique.

TON FEEDBACK DOIT OBLIGATOIREMENT SUIVRE CETTE STRUCTURE EXACTE (utilise ces titres de section) :

POINTS FORTS
[Liste ce que l'étudiant a bien fait : bonne démarche, examens pertinents demandés, diagnostic proche, traitement approprié]

POINTS À AMÉLIORER
[Liste les erreurs ou manques : examens leurres commandés, diagnostic erroné, traitement manquant ou inapproprié, justification trop courte]

DIAGNOSTIC ATTENDU
[Annonce clairement la bonne réponse et explique pourquoi ce diagnostic est correct au vu des symptômes et examens]

TRAITEMENT DE RÉFÉRENCE
[Donne le traitement attendu avec posologie, et explique la logique thérapeutique]

CONSEIL POUR LA PROCHAINE FOIS
[1 à 2 conseils pratiques pour progresser]

RÈGLES :
- Langage pédagogique, encourageant mais précis
- Réponse en français
- Jamais de listes à puces : rédige en prose continue
- Chaque section doit faire au minimum 2-3 phrases complètes
- Cite les actions concrètes de l'étudiant (examens commandés, diagnostic posé)${tutorContext ? `\n\nNotes du créateur du cas (contexte pédagogique) :\n${tutorContext}` : ''}`;

    const userMessage = `RÉSUMÉ DE LA SESSION :
Patient : ${caseRow.patient_name || 'Inconnu'}, ${caseRow.medical_history?.age || '?'} ans, ${caseRow.medical_history?.gender || '?'}
Motif de consultation : ${caseRow.consultation_reason || 'Non précisé'}
Symptômes principaux : ${caseRow.initial_symptoms || 'Non précisé'}

ACTIONS DE L'ÉTUDIANT :
- Examens commandés : ${requestedExams.length > 0 ? requestedExams.join(', ') : 'Aucun'}
  → Pertinents : ${orderedRelevant.length > 0 ? orderedRelevant.join(', ') : 'Aucun'}
  → Leurres commandés par erreur : ${orderedDecoys.length > 0 ? orderedDecoys.join(', ') : 'Aucun'}
- Diagnostic posé : ${studentDiagnosis}
- Justification clinique : ${studentPlan}
- Traitement proposé : ${studentTreatment ? `${studentTreatment.medication || ''} ${studentTreatment.dosage || ''} ${studentTreatment.frequency || ''}`.trim() : 'Non proposé'}

RÉPONSES ATTENDUES (ne pas révéler à l'avance dans le feedback — les annoncer dans les sections dédiées) :
- Diagnostic correct : ${expectedDiagnosis}
- Traitement de référence : ${expectedTreatment}${treatmentNotes ? `\n- Notes thérapeutiques : ${treatmentNotes}` : ''}
- Examens pertinents disponibles : ${relevantExams.join(', ') || 'Non listés'}

Rédige maintenant le feedback structuré complet.`;

    const response = await generateResponse(userMessage, systemPrompt);
    const { error: updErr } = await supabase.from('sessions').update({ feedback: response }).eq('id', session_id);
    if (updErr) console.warn('Failed updating feedback:', updErr.message);
    return res.json({ feedback: response });
  } catch (e) {
    return sendLlmError(res, e);
  }
});

// ─── LLM Providers Status (safe, no secrets) ───
router.get('/providers', async (req, res) => {
  const normalizeProviderName = (value) => {
    const raw = String(value || '').trim().toLowerCase();
    if (!raw) return '';
    if (raw === 'llama' || raw === 'llama-local' || raw === 'lmstudio') return 'llama';
    return raw;
  };

  const truthy = (value) => {
    const raw = String(value || '').trim().toLowerCase();
    return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
  };

  const groqRequired = truthy(process.env.GROQ_REQUIRED);
  const llamaRequired = truthy(process.env.LLAMA_REQUIRED || process.env.LMSTUDIO_REQUIRED);
  const configuredPrimary = normalizeProviderName(process.env.LLM_PROVIDER || process.env.LLM_PRIMARY);

  const groqEnabled = String(process.env.GROQ_API_KEY || '').trim().length > 0;
  const llamaModel = String(process.env.LLAMA_MODEL || process.env.OPENAI_MODEL || '').trim();
  const llamaEnabled = llamaModel.length > 0;

  const primary = groqRequired
    ? 'groq'
    : llamaRequired
      ? 'llama'
      : (configuredPrimary === 'groq' || configuredPrimary === 'llama')
        ? configuredPrimary
        : (groqEnabled ? 'groq' : 'llama');

  const other = primary === 'groq' ? 'llama' : 'groq';

  return res.json({
    primary,
    fallback: other,
    providers: {
      groq: {
        enabled: groqEnabled,
        required: groqRequired,
        baseUrl: String(process.env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1').trim(),
        model: String(process.env.GROQ_MODEL || 'llama-3.1-8b-instant').trim(),
      },
      llama: {
        enabled: llamaEnabled,
        required: llamaRequired,
        baseUrl: String(process.env.LLAMA_BASE_URL || process.env.OPENAI_BASE_URL || 'http://127.0.0.1:1234/v1').trim(),
        model: llamaModel,
      },
    },
  });
});

// ─── Diagnostics déjà utilisés par spécialité ───
router.get('/used-diagnoses/:specialtyId', async (req, res) => {
  const specialtyId = Number(req.params.specialtyId);
  if (!specialtyId) return res.status(400).json({ error: 'specialtyId required' });
  try {
    const { data: cases } = await supabase
      .from('cases')
      .select('disease_id,logic_medicale,status')
      .eq('specialty_id', specialtyId)
      .in('status', ['active', 'draft', 'archived']);

    const diagnoses = [...new Set(
      (cases || [])
        .map(c => (c.disease_id || c.logic_medicale || '').trim())
        .filter(Boolean)
    )].sort();

    return res.json({ specialtyId, count: diagnoses.length, diagnoses });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// ─── AI Case Generation ───
router.post('/generate-case', async (req, res) => {
  const { specialty_name, specialty_id, difficulty, excluded_diagnoses, strict_unique_specialty } = req.body;
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

    // Déduplication automatique : toujours activée si on connaît la spécialité.
    // On charge TOUS les diagnostics finals déjà publiés pour cette spécialité
    // (toutes saisons confondues) afin d'éviter les répétitions.
    let excludedDiagnoses = [];
    if (resolvedSpecialtyId) {
      const unique = new Map();
      const pageSize = 1000;
      for (let offset = 0; offset <= 10000; offset += pageSize) {
        const { data: existingCases, error: existingCasesErr } = await supabase
          .from('cases')
          .select('disease_id,logic_medicale,status')
          .eq('specialty_id', resolvedSpecialtyId)
          .in('status', ['active', 'draft', 'archived'])
          .range(offset, offset + pageSize - 1);

        if (existingCasesErr) {
          return res.status(500).json({ error: existingCasesErr.message });
        }

        for (const row of (existingCases || [])) {
          const raw = (row?.disease_id || row?.logic_medicale || '').toString().trim();
          if (!raw) continue;
          const key = normalizeDiagnosisKey(raw);
          if (key && !unique.has(key)) unique.set(key, raw);
        }

        if (!existingCases || existingCases.length < pageSize) break;
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

    // Le service llmService.js sélectionne la maladie depuis la matrice spécifique
    // à la spécialité (specialty_name). On ne force pas de diagnostic ici —
    // c'est le service qui choisit une maladie cohérente avec la spécialité,
    // et l'étudiant doit la découvrir via la simulation.
    const maxAttempts = 4;
    for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
      caseData = await generateCase(specialty_name, difficulty, {
        excludedDiagnoses,          // maladies déjà utilisées → éviter les répétitions
        forcedDiagnosis: '',        // laissé vide : le service choisit depuis la matrice
        generationSeed: `${Date.now()}-${Math.random()}-a${attempt}`,
      });

      lastDiagnosisKey = normalizeDiagnosisKey(caseData?.diagnosis || caseData?.disease_id || '');
      if (!lastDiagnosisKey) break;

      const alreadyUsed = excludedDiagnoses.some((d) => normalizeDiagnosisKey(d) === lastDiagnosisKey);
      if (!alreadyUsed) break;
    }

    const duplicate =
      lastDiagnosisKey && excludedDiagnoses.some((d) => normalizeDiagnosisKey(d) === lastDiagnosisKey);

    // Best-effort mode: never block bulk publishing at episode 8-9.
    // We still try to avoid duplicates, but we don't hard-fail if the pool is exhausted.
    return res.json({
      case: caseData,
      ...(duplicate
        ? {
            warning:
              "Diagnostic déjà présent dans la liste d'exclusion (pool probablement épuisé). Cas renvoyé quand même en mode best-effort.",
          }
        : {}),
    });
  } catch (e) {
    return sendLlmError(res, e);
  }
});

// ─── AI Quiz Generation (disease-specific) ───
router.post('/generate-quiz', async (req, res) => {
  const { specialty_id, question_count, disease, case_id, difficulty } = req.body || {};
  const specialtyId = Number(specialty_id);
  const caseId = Number(case_id);
  // Product rule: always generate exactly 30 questions.
  const questionCount = 30;
  const diseaseFilter = String(disease || '').trim();
  const requestedDifficulty = Number(difficulty);

  if (!Number.isFinite(specialtyId) || specialtyId <= 0) {
    return res.status(400).json({ error: 'specialty_id required' });
  }

  try {
    const { data: cases, error: casesError } = await supabase
      .from('cases')
      .select('id,patient_name,consultation_reason,initial_symptoms,medical_history,disease_id,logic_medicale,specialty_id,status,difficulty')
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

    if (Number.isFinite(requestedDifficulty) && requestedDifficulty > 0) {
      const parseDifficulty = (value) => {
        const n = Number(value);
        return Number.isFinite(n) ? n : null;
      };

      const exact = candidates.filter((c) => parseDifficulty(c?.difficulty) === requestedDifficulty);
      if (exact.length > 0) {
        candidates = exact;
      } else {
        // Fallback: pick cases with the closest available difficulty.
        // This avoids blocking quiz publication when data is not perfectly tagged.
        const valid = candidates.filter((c) => {
          const n = parseDifficulty(c?.difficulty);
          return n !== null && n > 0;
        });

        if (valid.length === 0) {
          // If difficulties are missing/unparseable, just ignore the filter.
          candidates = candidates;
        } else {
          let bestDelta = Number.POSITIVE_INFINITY;
          let best = [];
          for (const c of valid) {
            const n = parseDifficulty(c?.difficulty);
            if (n === null) continue;
            const delta = Math.abs(n - requestedDifficulty);
            if (delta < bestDelta) {
              bestDelta = delta;
              best = [c];
            } else if (delta === bestDelta) {
              best.push(c);
            }
          }
          if (best.length > 0) candidates = best;
        }
      }
    }
    if (Number.isFinite(caseId) && caseId > 0) {
      candidates = candidates.filter((c) => Number(c?.id) === caseId);
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
    return sendLlmError(res, e);
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
  const requestedSeason = Number(req.query.season || 0);
  if (!Number.isFinite(specialtyId) || specialtyId <= 0) {
    return res.status(400).json({ error: 'specialtyId invalide' });
  }

  try {
    const { data: rows, error } = await supabase
      .from('cases')
      .select('id,patient_name,consultation_reason,disease_id,logic_medicale,status,medical_history')
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
        const season = Number(row?.medical_history?.season);
        const episode = Number(row?.medical_history?.episode);
        return {
          id: row.id,
          disease,
          label,
          season: Number.isFinite(season) && season > 0 ? season : null,
          episode: Number.isFinite(episode) && episode > 0 ? episode : null,
        };
      })
      .filter(Boolean);

    const filtered = Number.isFinite(requestedSeason) && requestedSeason > 0
      ? cases.filter((c) => Number(c?.season) === requestedSeason)
      : cases;

    const sorted = [...filtered].sort((a, b) => {
      const sa = Number(a?.season) || 0;
      const sb = Number(b?.season) || 0;
      if (sa !== sb) return sa - sb;
      const ea = Number(a?.episode) || 0;
      const eb = Number(b?.episode) || 0;
      if (ea !== eb) return ea - eb;
      return Number(b?.id) - Number(a?.id);
    });

    return res.json({ cases: sorted });
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

  if (questions.length !== 30) {
    return res.status(400).json({
      error: `Le quiz doit contenir exactement 30 questions (reçu: ${questions.length}).`,
    });
  }

  const published = await loadPublishedQuizzes();

  // Guardrail: prevent publishing into a season that is already complete (10 episodes)
  // for the same specialty. This reduces accidental re-publication of Season 1.
  if (status === 'published') {
    const resolvedSpecialtyId = Number(quiz.specialty_id || payload.specialty_id || 0);
    const seasonNumber = Number(quiz.season ?? payload.season);
    const incomingEpisode = Number(quiz.episode ?? payload.episode ?? quiz.level ?? payload.level);
    const incomingKey = String(quiz.quiz_key || '').trim();
    if (
      Number.isFinite(resolvedSpecialtyId) &&
      resolvedSpecialtyId > 0 &&
      Number.isFinite(seasonNumber) &&
      seasonNumber > 0
    ) {
      const episodes = new Set(
        (published || [])
          .filter((q) => String(q?.status || 'published').toLowerCase() === 'published')
          .filter((q) => Number(q?.specialty_id) === resolvedSpecialtyId)
          .filter((q) => Number(q?.season) === seasonNumber)
          .map((q) => Number(q?.episode))
          .filter((n) => Number.isFinite(n) && n >= 1 && n <= 10),
      );
      if (episodes.size >= 10) {
        const isUpdatingExistingEpisode =
          (Number.isFinite(incomingEpisode) && episodes.has(incomingEpisode)) ||
          (incomingKey && (published || []).some((q) => String(q?.quiz_key || '').trim() === incomingKey));

        if (isUpdatingExistingEpisode) {
          // Allow updates (upsert) of an existing episode even if season is full.
          // This is important for fixing typos or regenerating a quiz.
        } else {
        return res.status(409).json({
          error: `La saison ${seasonNumber} est déjà publiée (10 épisodes). Publiez une nouvelle saison (ex: ${
            seasonNumber + 1
          }).`,
        });
        }
      }
    }
  }

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
    season: (() => {
      const n = Number(quiz.season ?? payload.season);
      return Number.isFinite(n) && n > 0 ? n : null;
    })(),
    episode: (() => {
      // Some admin UIs historically send the episode index as `level`.
      const n = Number(quiz.episode ?? payload.episode ?? quiz.level ?? payload.level);
      return Number.isFinite(n) && n > 0 ? n : null;
    })(),
    level: (() => {
      const n = Number(quiz.level ?? payload.level);
      return Number.isFinite(n) && n > 0 ? n : null;
    })(),
    difficulty: (() => {
      const n = Number(quiz.difficulty ?? payload.difficulty);
      return Number.isFinite(n) && n > 0 ? n : null;
    })(),
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

  await upsertQuiz({ ...row, created_at: row.created_at || new Date().toISOString() });
  return res.json({ quiz: row });
});

// ─── List published quizzes (mobile/player) ───
router.get('/published-quizzes', async (req, res) => {
  const status = String(req.query.status || 'published').trim().toLowerCase();
  const specialtyId = Number(req.query.specialty_id || 0);
  const season = Number(req.query.season || 0);
  const rows = await loadPublishedQuizzes();
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

  const filteredBySeason = Number.isFinite(season) && season > 0
    ? filtered.filter((q) => Number(q?.season) === season)
    : filtered;

  const sorted = [...filteredBySeason].sort((a, b) => {
    const sa = Number(a?.season) || 0;
    const sb = Number(b?.season) || 0;
    if (sa !== sb) return sa - sb;
    const ea = Number(a?.episode) || 0;
    const eb = Number(b?.episode) || 0;
    if (ea !== eb) return ea - eb;
    const ta = Date.parse(String(a?.updated_at || a?.created_at || '')) || 0;
    const tb = Date.parse(String(b?.updated_at || b?.created_at || '')) || 0;
    return tb - ta;
  });

  return res.json({ quizzes: sorted });
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

  const rows = await loadPublishedQuizzes();
  const existing = rows.find((q) => String(q?.id || '') === id);
  if (!existing) {
    return res.status(404).json({ error: 'quiz introuvable' });
  }

  const updates = {
    ...(typeof title === 'string' && title.trim() ? { title: title.trim() } : {}),
    ...(typeof disease === 'string' && disease.trim() ? { disease: disease.trim() } : {}),
    ...(nextStatus ? { status: nextStatus } : {}),
    updated_at: new Date().toISOString(),
  };

  await updateQuizById(id, updates);
  return res.json({ quiz: { ...existing, ...updates } });
});

// ─── Delete published quiz (admin) ───
router.delete('/published-quizzes/:id', async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) {
    return res.status(400).json({ error: 'id requis' });
  }

  const rows = await loadPublishedQuizzes();
  const removed = rows.find((q) => String(q?.id || '') === id);
  if (!removed) {
    return res.status(404).json({ error: 'quiz introuvable' });
  }

  await deleteQuizById(id);
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
    return sendLlmError(res, e);
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

    const { data: caseExams } = await supabase.from('case_exams').select('name,is_relevant').eq('case_id', case_id);
    const relevantExams = (caseExams || []).filter(e => e.is_relevant !== false).map(e => e.name);

    const mh = caseRow.medical_history || {};
    const type = (hint_type || 'general').toString().toLowerCase();

    const examList = relevantExams.length > 0
      ? `Examens disponibles dans ce cas : ${relevantExams.join(', ')}.`
      : '';

    const guidanceByType = {
      exam: `Donne un indice orienté vers un ou deux examens utiles parmi ceux disponibles dans ce cas. Ne cite PAS le diagnostic. ${examList}`,
      symptom: `Donne un indice orienté vers un symptôme ou signe clinique important à explorer chez ce patient.`,
      general: `Donne un indice de raisonnement global (interrogatoire, examen clinique, physiopathologie).`,
    };

    const prompt = `Tu es un tuteur médical bienveillant. L'étudiant travaille sur un cas clinique et demande un indice.

Cas: ${caseRow.consultation_reason || caseRow.patient_name}
Symptômes initiaux: ${caseRow.initial_symptoms || ''}
Spécialité: ${mh.specialty || ''}
Difficulté: ${caseRow.difficulty || 1}/3
${examList}

${guidanceByType[type] || guidanceByType.general}

Donne UN SEUL indice concis (2-3 phrases max) qui aide l'étudiant SANS révéler le diagnostic. Ne propose que des examens qui figurent dans la liste ci-dessus.

Réponds UNIQUEMENT avec l'indice, sans introduction ni conclusion.`;

    const hint = await generateResponse(prompt);
    return res.json({ hint });
  } catch (e) {
    return sendLlmError(res, e);
  }
});

module.exports = router;
