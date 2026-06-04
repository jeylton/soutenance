const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');
const { awardXP, checkAndAwardBadges, setLevelFromPoints } = require('./gamificationRoutes');
const { createNotification } = require('./notificationRoutes');
const { generateResponse } = require('../services/llmService');

router.get('/', async (req, res) => {
  const { case_id, has_feedback, user_id, is_exam } = req.query;
  try {
    let query = supabase.from('sessions').select('*,users(full_name,email),cases(patient_name,consultation_reason,avatar,disease_id,difficulty)').order('created_at', { ascending: false });
    if (case_id) query = query.eq('case_id', case_id);
    if (user_id) query = query.eq('user_id', user_id);
    if (has_feedback) query = query.not('feedback', 'is', null);
    if (is_exam === 'true') query = query.eq('is_exam', true);
    const { data, error } = await query;
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ sessions: data || [] });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const { data, error } = await supabase.from('sessions').select('*').eq('id', id).single();
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    return res.json({ session: data });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.post('/', async (req, res) => {
  const { user_id, case_id, is_exam, exam_assignment_id } = req.body;
  if (!user_id || !case_id) {
    return res.status(400).json({ error: 'user_id and case_id required' });
  }
  try {
    const insertData = {
      user_id,
      case_id,
      progress: { requested_exams: [], conclusion: null },
    };
    if (is_exam) insertData.is_exam = true;
    if (exam_assignment_id) insertData.exam_assignment_id = exam_assignment_id;

    const { data, error } = await supabase
      .from('sessions')
      .insert([insertData])
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

router.post('/:id/exams', async (req, res) => {
  const { id } = req.params;
  const { exam_name } = req.body;
  if (!exam_name) {
    return res.status(400).json({ error: 'exam_name required' });
  }
  try {
    const { data: sessionRow, error: sErr } = await supabase.from('sessions').select('*').eq('id', id).single();
    if (sErr) {
      return res.status(500).json({ error: sErr.message });
    }
    const { data: examRow, error: eErr } = await supabase
      .from('case_exams')
      .select('name,result')
      .eq('case_id', sessionRow.case_id)
      .eq('name', exam_name)
      .single();
    if (eErr) {
      return res.status(404).json({ error: 'Exam not found for case' });
    }
    const progress = sessionRow.progress || { requested_exams: [] };
    const already = (progress.requested_exams || []).find((e) => e.name === exam_name);
    if (!already) {
      progress.requested_exams = [...(progress.requested_exams || []), examRow];
      const { error: uErr } = await supabase.from('sessions').update({ progress }).eq('id', id);
      if (uErr) {
        console.warn('Failed to update session progress:', uErr.message);
      }
    }
    return res.json({ exam: examRow });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.get('/:id/exams', async (req, res) => {
  const { id } = req.params;
  try {
    const { data: sessionRow, error: sErr } = await supabase.from('sessions').select('progress').eq('id', id).single();
    if (sErr) {
      return res.status(500).json({ error: sErr.message });
    }
    const exams = sessionRow.progress?.requested_exams || [];
    return res.json({ exams });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

router.post('/:id/conclude', async (req, res) => {
  const { id } = req.params;
  const { diagnosis, plan, time_spent, treatment } = req.body;
  // treatment = { medication, dosage, frequency } from student
  try {
    const { data: sessionRow, error: sErr } = await supabase.from('sessions').select('*').eq('id', id).single();
    if (sErr) {
      return res.status(500).json({ error: sErr.message });
    }

    // Get the case to compare diagnosis + treatment
    const { data: caseRow } = await supabase.from('cases').select('disease_id,difficulty,medical_history').eq('id', sessionRow.case_id).single();

    const progress = sessionRow.progress || {};
    progress.conclusion = { diagnosis, plan, time_spent, treatment: treatment || null };

    // ─── Scoring Algorithm ───
    let score = 0;
    const maxScore = 20;

    // ─── Points Algorithm (0-100) for level progression ───
    let pointsEarned = 0;
    const pointBreakdown = {
      diagnosis: 0,
      exams: 0,
      reasoning: 0,
      treatment: 0,
      time: 0,
    };

    // 1. Diagnosis accuracy (0-7 points)
    if (caseRow && caseRow.disease_id && diagnosis) {
      const expected = caseRow.disease_id.toLowerCase().trim();
      const given = diagnosis.toLowerCase().trim();
      if (given === expected || given.includes(expected) || expected.includes(given)) {
        score += 7;
        pointBreakdown.diagnosis = 35;
      } else if (given.length > 3 && expected.length > 3) {
        const expectedWords = expected.split(/[\s_-]+/);
        const givenWords = given.split(/[\s_-]+/);
        const overlap = givenWords.filter(w => expectedWords.some(ew => ew.includes(w) || w.includes(ew))).length;
        const overlapScore = Math.min(Math.round((overlap / expectedWords.length) * 5), 5);
        score += overlapScore;
        pointBreakdown.diagnosis = Math.min(Math.round((overlapScore / 7) * 35), 25);
      }
    } else if (diagnosis && diagnosis.length > 5) {
      score += 3;
      pointBreakdown.diagnosis = 15;
    }

    // 2. Exams ordered (0-4 points)
    const requestedExams = progress.requested_exams || [];
    const examRelevanceMap = caseRow?.medical_history?.exam_relevance || {};
    const requestedNames = [...new Set(requestedExams.map((e) => (e?.name || '').toString().trim()).filter(Boolean))];
    const allExamNames = Object.keys(examRelevanceMap);
    const relevantExamNames = allExamNames.filter((name) => examRelevanceMap[name] !== false);
    const totalRelevant = relevantExamNames.length;

    const relevantRequested = requestedNames.filter((name) => examRelevanceMap[name] !== false).length;
    const decoyRequested = requestedNames.filter((name) => examRelevanceMap[name] === false).length;

    if (requestedNames.length > 0 && totalRelevant > 0) {
      const recall = relevantRequested / Math.max(1, totalRelevant);
      const precision = relevantRequested / Math.max(1, requestedNames.length);
      const decoyRate = decoyRequested / Math.max(1, requestedNames.length);

      const examScoreFloat = Math.max(0, Math.min(4, (recall * 3) + (precision * 1) - (decoyRate * 2)));
      const examScore = Math.round(examScoreFloat);
      score += examScore;
      pointBreakdown.exams = Math.round((examScoreFloat / 4) * 20);
    } else if (requestedNames.length > 0) {
      score += 1;
      pointBreakdown.exams = 5;
    }

    // 3. Clinical justification (0-3 points)
    const justification = plan || '';
    if (justification.length > 100) {
      score += 3;
      pointBreakdown.reasoning = 15;
    }
    else if (justification.length > 50) {
      score += 2;
      pointBreakdown.reasoning = 10;
    }
    else if (justification.length > 20) {
      score += 1;
      pointBreakdown.reasoning = 5;
    }

    // 4. Treatment evaluation (0-3 points)
    const expectedTreatment = caseRow?.medical_history?.treatment || [];
    if (treatment && treatment.medication && treatment.medication.trim().length > 2) {
      let treatScore = 1; // At least proposed something
      // Check if medication matches any expected treatment
      if (expectedTreatment.length > 0) {
        const studentMed = treatment.medication.toLowerCase().trim();
        const matchesMed = expectedTreatment.some(t =>
          studentMed.includes((t.medication || '').toLowerCase()) ||
          (t.medication || '').toLowerCase().includes(studentMed)
        );
        if (matchesMed) treatScore = 2;
      }
      // Dosage & frequency give extra point
      if (treatment.dosage && treatment.dosage.trim().length > 1 &&
          treatment.frequency && treatment.frequency.trim().length > 1) {
        treatScore = Math.min(treatScore + 1, 3);
      }
      score += treatScore;
      pointBreakdown.treatment = Math.min(treatScore * 5, 15);
    }

    // 5. Time efficiency (0-2 points)
    const timeMin = (time_spent || 0) / 60;
    if (timeMin > 0 && timeMin <= 15) {
      score += 2;
      pointBreakdown.time = 15;
    }
    else if (timeMin > 15 && timeMin <= 30) {
      score += 1;
      pointBreakdown.time = 8;
    }
    else if (timeMin > 30 && timeMin <= 45) {
      pointBreakdown.time = 4;
    }

    // 6. Difficulty bonus (0-1 point)
    if (caseRow && caseRow.difficulty >= 3 && score >= 12) score += 1;

    score = Math.min(score, maxScore);
    pointsEarned = Object.values(pointBreakdown).reduce((a, b) => a + b, 0);
    pointsEarned = Math.max(0, Math.min(100, pointsEarned));

    progress.points = {
      earned: pointsEarned,
      breakdown: pointBreakdown,
      rule: 'diagnosis+exams+reasoning+treatment+time',
    };

    const { error: uErr } = await supabase
      .from('sessions')
      .update({ progress, score, time_spent: time_spent || 0 })
      .eq('id', id);
    if (uErr) {
      return res.status(500).json({ error: uErr.message });
    }

    // Gamification: Award XP (exams give 1.5x bonus)
    let totalPoints = pointsEarned;
    let updatedLevel = null;
    let previousCompletions = 0;
    let rewardMultiplier = 1;
    if (sessionRow.user_id) {
      const { count: completedSameCaseCount } = await supabase
        .from('sessions')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', sessionRow.user_id)
        .eq('case_id', sessionRow.case_id)
        .not('score', 'is', null)
        .neq('id', id);

      previousCompletions = completedSameCaseCount || 0;
      const replaySteps = [1, 0.55, 0.3, 0.15, 0.1];
      rewardMultiplier = replaySteps[Math.min(previousCompletions, replaySteps.length - 1)];

      const baseXP = score * 10 + 50;
      const xpBaseWithExam = sessionRow.is_exam ? Math.round(baseXP * 1.5) : baseXP;
      const xpPoints = Math.max(1, Math.round(xpBaseWithExam * rewardMultiplier));
      pointsEarned = Math.max(0, Math.round(pointsEarned * rewardMultiplier));
      progress.points = {
        ...progress.points,
        earned: pointsEarned,
        replay_multiplier: rewardMultiplier,
        previous_completions: previousCompletions,
      };

      const { error: replayPatchError } = await supabase
        .from('sessions')
        .update({ progress })
        .eq('id', id);
      if (replayPatchError) {
        console.warn('Failed to update replay-adjusted points:', replayPatchError.message);
      }

      const examLabel = sessionRow.is_exam ? ' (Bonus examen x1.5)' : '';
      const replayLabel = previousCompletions > 0
        ? ` (rejoué x${previousCompletions + 1}, multiplicateur ${rewardMultiplier})`
        : '';

      const { data: userSessions } = await supabase
        .from('sessions')
        .select('progress,score')
        .eq('user_id', sessionRow.user_id)
        .not('score', 'is', null);

      if (Array.isArray(userSessions)) {
        totalPoints = userSessions.reduce((acc, s) => {
          const earned = Number(s?.progress?.points?.earned);
          if (Number.isFinite(earned)) return acc + earned;
          const fallbackFromScore = Math.max(0, Math.min(100, Math.round((Number(s?.score) || 0) * 5)));
          return acc + fallbackFromScore;
        }, 0);
      }

      await awardXP(sessionRow.user_id, xpPoints);
      updatedLevel = await setLevelFromPoints(sessionRow.user_id, totalPoints);
      await checkAndAwardBadges(sessionRow.user_id);
      await createNotification(
        sessionRow.user_id,
        'Session terminée !',
        `Score: ${score}/20. +${xpPoints} XP${examLabel}${replayLabel}. +${pointsEarned} pts progression.`,
        'feedback'
      );
    }

    // Auto-generate tutor feedback via LLM (async, non-blocking)
    (async () => {
      try {
        const { data: fullCase } = await supabase.from('cases').select('*').eq('id', sessionRow.case_id).single();
        const base = fullCase?.prompt_tuteur || '';
        const logic = fullCase?.logic_medicale || '';
        const treatmentRef = fullCase?.medical_history?.treatment || [];
        const treatmentNotes = fullCase?.medical_history?.treatment_notes || '';
        const progressStr = JSON.stringify(progress);
        const prompt = [
          base,
          'Tu es un tuteur pédagogique en médecine. Analyse le raisonnement clinique de l\'étudiant.',
          `Cas: ${fullCase?.patient_name || ''} — ${fullCase?.consultation_reason || ''}`,
          'Diagnostic attendu: ' + logic,
          'Traitement de référence: ' + JSON.stringify(treatmentRef),
          'Notes thérapeutiques: ' + treatmentNotes,
          'Actions de l\'étudiant: ' + progressStr,
          `Score obtenu: ${score}/20`,
          'Fournis un feedback structuré en français: Points forts, Erreurs identifiées, Analyse du traitement proposé (comparer avec le traitement de référence), Recommandations pour progresser.',
        ].join('\n');
        const fallbackFeedback = [
          'Feedback tuteur (mode dégradé):',
          `Score: ${score}/20`,
          logic ? `Diagnostic attendu: ${logic}` : null,
          treatmentRef && treatmentRef.length > 0
            ? `Traitement de référence: ${JSON.stringify(treatmentRef)}`
            : 'Traitement de référence: non défini pour ce cas.',
          treatmentNotes ? `Notes thérapeutiques: ${treatmentNotes}` : null,
          'Résumé: la génération IA du feedback n\'est pas disponible pour le moment. Utilisez le score et le traitement de référence pour vous auto-corriger, puis rejouez le cas.',
        ].filter(Boolean).join('\n');

        let feedback = null;
        try {
          feedback = await generateResponse(prompt);
        } catch (llmErr) {
          console.warn('[AutoFeedback] LLM error:', llmErr.message);
        }

        const finalFeedback = (feedback && String(feedback).trim().length > 0)
          ? feedback
          : fallbackFeedback;

        await supabase.from('sessions').update({ feedback: finalFeedback }).eq('id', id);
        console.log(`[AutoFeedback] Stored for session ${id}`);
      } catch (fbErr) {
        console.warn('[AutoFeedback] Error:', fbErr.message);
      }
    })();

    return res.json({
      ok: true,
      score,
      points_earned: pointsEarned,
      points_breakdown: pointBreakdown,
      previous_completions: previousCompletions,
      reward_multiplier: rewardMultiplier,
      total_points: totalPoints,
      level: updatedLevel,
      expected_treatment: expectedTreatment,
      treatment_notes: caseRow?.medical_history?.treatment_notes || null,
      expected_diagnosis: caseRow?.disease_id || null,
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
