const axios = require('axios');
const { resolveAvatarProfile } = require('./avatarVoiceProfile');

// ═══════════════════════════════════════════════════════════
//  DICA CLINIC — Intelligent Patient LLM Service
//  Priority: 1) Groq (free cloud) → 2) Ollama (local) → 3) Smart fallback
// ═══════════════════════════════════════════════════════════

// ─── 1. GROQ Cloud LLM (free, fast, intelligent) ───

async function callGroq(systemPrompt, userMessage) {
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) return null;

    try {
        const response = await axios.post(
            'https://api.groq.com/openai/v1/chat/completions',
            {
                model: process.env.GROQ_MODEL || 'llama-3.3-70b-versatile',
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: userMessage },
                ],
                temperature: 0.7,
                max_tokens: 300,
            },
            {
                headers: {
                    'Authorization': `Bearer ${apiKey}`,
                    'Content-Type': 'application/json',
                },
                timeout: 10000,
            }
        );

        const reply = response.data?.choices?.[0]?.message?.content;
        if (reply) {
            console.log('✓ Groq response received');
            return reply.trim();
        }
        return null;
    } catch (error) {
        console.warn('Groq unavailable:', error.response?.data?.error?.message || error.message);
        return null;
    }
}

// ─── 2. Ollama Local LLM ───

async function callOllama(prompt) {
    if (!process.env.LLM_API_URL) return null;

    try {
        const response = await axios.post(
            process.env.LLM_API_URL,
            {
                model: process.env.LLM_MODEL || 'llama2',
                prompt: prompt,
                stream: false,
            },
            { timeout: 5000 }
        );
        if (response.data?.response) {
            console.log('✓ Ollama response received');
            return response.data.response.trim();
        }
        return null;
    } catch (error) {
        console.warn('Ollama unavailable:', error.message);
        return null;
    }
}

// ─── 3. Smart fallback (keyword-based, last resort) ───

function smartFallback(prompt) {
    const symptomsMatch = prompt.match(/Symptômes initiaux:\s*(.+)/i);
    const historyMatch = prompt.match(/Historique médical:\s*(.+)/i);
    const questionMatch = prompt.match(/Question du médecin:\s*(.+)/i);

    const symptoms = symptomsMatch ? symptomsMatch[1].trim() : '';
    const history = historyMatch ? historyMatch[1].trim() : '';
    const question = questionMatch ? questionMatch[1].trim().toLowerCase() : '';

    if (!question) {
        return symptoms
            ? `Bonjour Docteur. ${symptoms}. Je suis inquiet et j'aimerais avoir votre avis.`
            : "Bonjour Docteur. Je ne me sens pas très bien ces derniers temps.";
    }

    // Greetings
    if (/^(bonjour|salut|bonsoir|hello|coucou)/i.test(question)) {
        return symptoms
            ? `Bonjour Docteur. Merci de me recevoir. En fait, ${symptoms.toLowerCase()}.`
            : "Bonjour Docteur. Merci de me recevoir. Je ne me sens pas bien depuis quelque temps.";
    }

    // Sleep
    if (/sommeil|dorm|dort|nuit|insomnie|r[eé]veil|repos/i.test(question)) {
        return "Je dors mal depuis que ces symptômes ont commencé. Je me réveille souvent la nuit à cause de l'inconfort.";
    }

    // Fatigue
    if (/fatigu[eé]|[eé]puis[eé]|[eé]nergie|force/i.test(question)) {
        return symptoms.match(/fatigu|asth[eé]n/i)
            ? "Oui, je suis très fatigué. C'est d'ailleurs un de mes symptômes principaux, cette fatigue qui ne passe pas."
            : "Je me sens un peu fatigué, mais c'est surtout mes autres symptômes qui me préoccupent.";
    }

    // Duration
    if (/depuis|combien.*temps|quand.*commenc|d[eé]but|dur[eé]e|il y a/i.test(question)) {
        return "Ça a commencé il y a environ une semaine, mais ça s'aggrave de jour en jour.";
    }

    // Symptoms / what's wrong
    if (/qu.*(est-ce|problème|plaig|arrive|amène|mal|douleur|ressent)/i.test(question) ||
        /comment.*(?:allez|sentez|vous)/i.test(question) ||
        /quel.*(?:symptôme|problème|plainte|motif)/i.test(question)) {
        return symptoms
            ? `En fait Docteur, ${symptoms.toLowerCase()}. C'est ce qui m'inquiète le plus.`
            : "Je me sens fatigué et j'ai des douleurs qui m'empêchent de mener mes activités normalement.";
    }

    // Location
    if (/o[uù].*(?:douleur|mal|fait|exactement|localis)|localis|endroit|zone|o[uù].*mal/i.test(question)) {
        return "C'est assez localisé, je peux vous montrer exactement l'endroit où j'ai mal.";
    }

    // Medical history
    if (/ant[eé]c[eé]d|historique|pass[eé]|d[eé]j[aà].*eu|op[eé]ra|hospitalis|chirurg/i.test(question)) {
        if (history && history !== '{}' && history.length > 5) {
            try {
                const h = JSON.parse(history);
                if (typeof h === 'object' && Object.keys(h).length > 0) {
                    const items = Object.entries(h).map(([k, v]) => {
                        if (typeof v === 'object') v = JSON.stringify(v);
                        return `${k}: ${v}`;
                    }).join(', ');
                    return `Dans mes antécédents, j'ai ${items}. À part ça, rien de particulier.`;
                }
            } catch (_) {
                return `Dans mes antécédents, ${history}. Sinon, je n'ai pas eu de problèmes majeurs.`;
            }
        }
        return "Non, je n'ai pas d'antécédents médicaux particuliers.";
    }

    // Allergies
    if (/allerg/i.test(question)) return "Non, je n'ai pas d'allergies connues.";

    // Medications
    if (/m[eé]dicament|traitement|prend|prenez|comprim/i.test(question)) {
        return "Je n'ai pas pris de médicaments particuliers. Peut-être du paracétamol de temps en temps.";
    }

    // Family
    if (/famille|familial|parent|p[eè]re|m[eè]re|fr[eè]re/i.test(question)) {
        return "Pas vraiment de maladies particulières dans ma famille.";
    }

    // Fever
    if (/fi[eè]vre|temp[eé]rature|chaud|frisson/i.test(question)) {
        return symptoms.match(/fi[eè]vre|temp[eé]rature|f[eé]brile/i)
            ? "Oui, j'ai eu de la fièvre, surtout le soir. Je dirais autour de 38,5°C."
            : "Non, je n'ai pas remarqué de fièvre.";
    }

    // Appetite
    if (/app[eé]tit|mang|nourrit|repas|faim|poids/i.test(question)) {
        return "Mon appétit a diminué ces derniers jours. Je mange moins qu'avant.";
    }

    // Examination
    if (/examen|ausculter|examiner|toucher|palper|test|analyse|bilan|radio/i.test(question)) {
        return "Oui bien sûr, Docteur. Faites ce que vous jugez nécessaire.";
    }

    // Tobacco / alcohol
    if (/tabac|fum|cigarette|alcool|boi|drogue/i.test(question)) {
        return "Non, je ne fume pas et je bois très rarement.";
    }

    // Default
    if (symptoms) {
        return `C'est une bonne question. Ce qui me préoccupe surtout c'est ${symptoms.toLowerCase()}.`;
    }
    return "Je ne suis pas sûr, Docteur. Pouvez-vous reformuler votre question ?";
}

function stripInterpretationFromResult(value) {
    if (value == null) return '';
    let text = String(value).replace(/\r/g, '').trim();
    if (!text) return '';

    text = text
        .split('\n')
        .filter((line) => !/^\s*(interpr[eé]tation|interpretation|conclusion|impression|diagnostic probable|orientation diagnostique)\s*[:\-]/i.test(line))
        .join('\n')
        .trim();

    text = text.replace(/\s*(compatible avec|en faveur de|sugg[eè]re|[eé]voque|oriente vers)\b.*$/i, '').trim();
    return text;
}

const MALE_FIRST_NAMES = ['Amadou', 'Moussa', 'Ibrahima', 'Mamadou', 'Issa', 'Yao', 'Koffi', 'Karim', 'Paul', 'Jean'];
const FEMALE_FIRST_NAMES = ['Awa', 'Fatou', 'Mariam', 'Aminata', 'Nadia', 'Aissatou', 'Clarisse', 'Jeanne', 'Nafi', 'Sophie'];
const FAMILY_NAMES = ['Diallo', 'Traore', 'Kone', 'Ouattara', 'Keita', 'Ndiaye', 'Mensah', 'Bamba', 'Camara', 'Dupont'];

function normalizeGeneratedGender(gender) {
    const g = (gender || '').toString().trim().toLowerCase();
    if (g.startsWith('f')) return 'Féminin';
    if (g.startsWith('m')) return 'Masculin';
    return '';
}

function clampGeneratedAge(age) {
    const n = Number.parseInt(age, 10);
    if (!Number.isFinite(n)) return null;
    if (n < 1) return 1;
    if (n > 95) return 95;
    return n;
}

function pickBySeed(list, seed) {
    if (!Array.isArray(list) || list.length === 0) return '';
    const s = (seed || '').toString();
    let hash = 0;
    for (let i = 0; i < s.length; i += 1) {
        hash = ((hash * 31) + s.charCodeAt(i)) >>> 0;
    }
    return list[hash % list.length];
}

function buildConsistentName(currentName, gender, seed) {
    const cleaned = (currentName || '')
        .toString()
        .replace(/^(mr|m\.|mme|mlle|madame|monsieur)\s+/i, '')
        .replace(/\s+/g, ' ')
        .trim();

    if (!cleaned) {
        const first = pickBySeed(gender === 'Féminin' ? FEMALE_FIRST_NAMES : MALE_FIRST_NAMES, seed);
        const last = pickBySeed(FAMILY_NAMES, `${seed}|family`);
        return `${first} ${last}`.trim();
    }

    const parts = cleaned.split(' ').filter(Boolean);
    if (parts.length === 0) {
        const first = pickBySeed(gender === 'Féminin' ? FEMALE_FIRST_NAMES : MALE_FIRST_NAMES, seed);
        const last = pickBySeed(FAMILY_NAMES, `${seed}|family`);
        return `${first} ${last}`.trim();
    }

    const first = parts[0];
    const knownMale = MALE_FIRST_NAMES.map((n) => n.toLowerCase());
    const knownFemale = FEMALE_FIRST_NAMES.map((n) => n.toLowerCase());
    const firstLower = first.toLowerCase();
    const looksMale = knownMale.includes(firstLower);
    const looksFemale = knownFemale.includes(firstLower);

    if ((gender === 'Féminin' && looksMale) || (gender === 'Masculin' && looksFemale)) {
        const replacement = pickBySeed(gender === 'Féminin' ? FEMALE_FIRST_NAMES : MALE_FIRST_NAMES, seed);
        return [replacement, ...parts.slice(1)].join(' ').trim();
    }

    return cleaned;
}

function inferDefaultsFromHint(hint) {
    const h = (hint || '').toString().toLowerCase();
    if (h.includes('child')) {
        return {
            age: 10,
            gender: h.includes('female') ? 'Féminin' : 'Masculin',
        };
    }
    if (h.includes('old')) {
        return {
            age: 68,
            gender: h.includes('female') ? 'Féminin' : 'Masculin',
        };
    }
    if (h.includes('female')) {
        return { age: 32, gender: 'Féminin' };
    }
    if (h.includes('male')) {
        return { age: 34, gender: 'Masculin' };
    }
    return { age: 34, gender: 'Masculin' };
}

function sanitizeGeneratedCase(payload) {
    if (!payload || typeof payload !== 'object') return payload;

    const hinted = inferDefaultsFromHint(payload.avatar_hint);
    const rawGender = normalizeGeneratedGender(payload.gender) || hinted.gender;
    const rawAge = clampGeneratedAge(payload.age) ?? hinted.age;
    const profile = resolveAvatarProfile({
        avatar: payload.avatar || payload.avatar_hint,
        age: rawAge,
        gender: rawGender,
    });

    const seed = `${payload.diagnosis || ''}|${payload.consultation_reason || ''}|${rawAge}|${rawGender}`;
    const patientName = buildConsistentName(payload.patient_name, rawGender, seed);

    const exams = Array.isArray(payload.exams)
        ? payload.exams
            .filter((e) => e && e.name)
            .map((e) => ({
                ...e,
                result: stripInterpretationFromResult(e.result || ''),
                is_relevant: e.is_relevant !== false,
            }))
        : [];
    return {
        ...payload,
        patient_name: patientName,
        age: String(rawAge),
        gender: rawGender,
        avatar_hint: profile?.hint || payload.avatar_hint || 'male_young',
        avatar: profile?.path || payload.avatar || null,
        exams,
    };
}

// ═══════════════════════════════════════════════════════════
//  Main response generator — tries Groq → Ollama → Fallback
// ═══════════════════════════════════════════════════════════

const generatePatientResponse = async (caseData, question) => {
    // Build a rich system prompt for the LLM
    const patientName = caseData.patient_name || 'un patient';
    const age = caseData.medical_history?.age || '';
    const gender = caseData.medical_history?.gender || '';
    const symptoms = caseData.initial_symptoms || caseData.consultation_reason || '';
    const history = caseData.medical_history || {};
    const basePrompt = caseData.prompt_patient || '';
    const diagnosis = caseData.expected_diagnosis || '';

    const systemPrompt = `Tu es ${patientName}, ${age ? `${age} ans` : 'un adulte'}, ${gender || 'patient'}.
Tu joues le rôle d'un patient dans une simulation médicale pour des étudiants en médecine.

CONTEXTE MÉDICAL (informations que tu connais en tant que patient) :
- Motif de consultation : ${caseData.consultation_reason || symptoms}
- Tes symptômes : ${symptoms}
- Tes antécédents personnels : ${JSON.stringify(history.antecedents?.perso || history.antecedents || 'Aucun particulier')}
- Antécédents familiaux : ${JSON.stringify(history.antecedents?.familiaux || 'Aucun particulier')}
- Habitudes de vie : ${JSON.stringify(history.habits || 'Non spécifié')}
- Allergies : ${JSON.stringify(history.allergies || 'Aucune connue')}
${basePrompt ? `\nInstructions spéciales : ${basePrompt}` : ''}

RÈGLES IMPORTANTES :
1. Réponds UNIQUEMENT en tant que patient. Tu ne donnes JAMAIS de diagnostic médical.
2. Tu ne connais PAS le diagnostic (${diagnosis}). Tu ne le révèles JAMAIS.
3. Réponds de façon naturelle, comme un vrai patient qui parle à son médecin.
4. Utilise un langage simple et naturel (pas de jargon médical).
5. Si le médecin te pose une question sur un symptôme que tu n'as pas, dis clairement que non.
6. Si le médecin te demande quelque chose que tu ne sais pas, dis que tu ne sais pas.
7. Tes réponses doivent être courtes (2-3 phrases maximum).
8. Réponds en français.
9. Sois cohérent avec tes symptômes et ton histoire médicale décrite ci-dessus.
10. Tu peux exprimer de l'inquiétude, de la douleur ou de l'incertitude comme un vrai patient.`;

    const userMessage = question || "Bonjour Docteur.";

    // 1) Try Groq (free cloud LLM — intelligent responses)
    const groqReply = await callGroq(systemPrompt, userMessage);
    if (groqReply) return groqReply;

    // 2) Try Ollama (local LLM)
    const ollamaPrompt = [
        systemPrompt,
        `\nQuestion du médecin: ${userMessage}`,
        '\nRéponse du patient:'
    ].join('\n');
    const ollamaReply = await callOllama(ollamaPrompt);
    if (ollamaReply) return ollamaReply;

    // 3) Fallback (keyword-based)
    console.warn('⚠ Using keyword fallback (no LLM available)');
    const fallbackPrompt = [
        `Symptômes initiaux: ${symptoms}`,
        `Historique médical: ${JSON.stringify(history)}`,
        `Question du médecin: ${userMessage}`,
    ].join('\n');
    return smartFallback(fallbackPrompt);
};

// Legacy function for tutor (still uses prompt-based approach)
const generateResponse = async (prompt) => {
    // Try Groq first
    const groqReply = await callGroq(
        'Tu es un tuteur pédagogique médical. Analyse le raisonnement clinique de l\'étudiant et fournis un feedback structuré en français.',
        prompt
    );
    if (groqReply) return groqReply;

    // Try Ollama
    const ollamaReply = await callOllama(prompt);
    if (ollamaReply) return ollamaReply;

    // Fallback
    return "Feedback indisponible pour le moment. Veuillez réessayer plus tard.";
};

// ═══════════════════════════════════════════════════════════
//  AI Case Generation — generates a full clinical case
// ═══════════════════════════════════════════════════════════

const generateCase = async (specialtyName, difficulty, options = {}) => {
    const excludedDiagnoses = Array.isArray(options.excludedDiagnoses) ? options.excludedDiagnoses : [];
    const generationSeed = String(options.generationSeed || '').trim();
    const forcedDiagnosisInput = String(options.forcedDiagnosis || '').trim();
    const diffLabel = ['très facile', 'facile', 'intermédiaire', 'difficile', 'très difficile'][Math.min(difficulty - 1, 4)];

    const specialtyDiseaseMatrix = {
        cardiologie: {
            easy: ['Hypertension artérielle essentielle', 'Insuffisance cardiaque gauche décompensée'],
            medium: ['Syndrome coronarien aigu sans sus-décalage ST', 'Fibrillation auriculaire rapide'],
            hard: ['Tamponnade péricardique', 'Dissection aortique de type B'],
        },
        pneumologie: {
            easy: ['Asthme aigu simple', 'Pneumonie communautaire lobaire'],
            medium: ['Embolie pulmonaire intermédiaire', 'Exacerbation aiguë de BPCO'],
            hard: ['Pneumothorax compressif', 'SDRA débutant'],
        },
        pediatrie: {
            easy: ['Otite moyenne aiguë', 'Gastro-entérite aiguë simple'],
            medium: ['Bronchiolite modérée', 'Pyélonéphrite aiguë de l\'enfant'],
            hard: ['Méningite bactérienne pédiatrique', 'Sepsis néonatal tardif'],
        },
        gynecologie: {
            easy: ['Vaginose bactérienne', 'Dysménorrhée primaire'],
            medium: ['Maladie inflammatoire pelvienne', 'Grossesse extra-utérine non rompue'],
            hard: ['Pré-éclampsie sévère', 'Hémorragie du post-partum'],
        },
        neurologie: {
            easy: ['Migraine sans aura', 'Vertige positionnel paroxystique bénin'],
            medium: ['AVC ischémique sylvien', 'Syndrome méningé viral'],
            hard: ['Hémorragie sous-arachnoïdienne', 'Encéphalite herpétique'],
        },
        nephrologie: {
            easy: ['Colique néphrétique simple', 'Infection urinaire basse'],
            medium: ['Pyélonéphrite aiguë', 'Insuffisance rénale aiguë fonctionnelle'],
            hard: ['Syndrome néphrotique impur', 'Hyperkaliémie menaçante sur insuffisance rénale'],
        },
    };

    const normalizeSpecialtyKey = (name) =>
        String(name || '')
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .trim();

    const specialtyKey = normalizeSpecialtyKey(specialtyName);
    const matchedKey = Object.keys(specialtyDiseaseMatrix).find((k) => specialtyKey.includes(k)) || null;
    const diseasePool = matchedKey ? specialtyDiseaseMatrix[matchedKey] : null;

    const diseaseTier = difficulty <= 2 ? 'easy' : (difficulty === 3 ? 'medium' : 'hard');
    const targetDiseases = diseasePool ? diseasePool[diseaseTier] : [];
    const alternativeDiseases = diseasePool
        ? [...(diseasePool.easy || []), ...(diseasePool.medium || []), ...(diseasePool.hard || [])].filter((d) => !targetDiseases.includes(d))
        : [];

    const normalizeDiagnosis = (value) =>
        String(value || '')
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/[^a-z0-9]+/g, ' ')
            .trim();

    const excludedSet = new Set(excludedDiagnoses.map((d) => normalizeDiagnosis(d)).filter(Boolean));
    const availableTargetDiseases = targetDiseases.filter((d) => !excludedSet.has(normalizeDiagnosis(d)));
    const availableAlternativeDiseases = alternativeDiseases.filter((d) => !excludedSet.has(normalizeDiagnosis(d)));

    const forcedDiagnosisPool = availableTargetDiseases.length > 0
        ? availableTargetDiseases
        : availableAlternativeDiseases;
    const forcedDiagnosis = forcedDiagnosisInput
        || (forcedDiagnosisPool.length > 0
            ? forcedDiagnosisPool[Math.floor(Math.random() * forcedDiagnosisPool.length)]
            : '');

    // Scale decoy exams and differential complexity by difficulty
    const decoyCount = [0, 1, 2, 3, 4][Math.min(difficulty - 1, 4)];
    const relevantCount = [3, 3, 4, 4, 5][Math.min(difficulty - 1, 4)];
    const diffDiagCount = [0, 1, 2, 3, 4][Math.min(difficulty - 1, 4)];

    const systemPrompt = `Tu es un professeur de médecine expert. Tu dois générer un cas clinique réaliste et pédagogique pour des étudiants en médecine.

Le cas doit être en spécialité "${specialtyName}" avec un niveau de difficulté "${diffLabel}" (${difficulty}/5).

Tu dois répondre UNIQUEMENT avec un objet JSON valide (sans commentaires, sans markdown, sans backticks) avec cette structure exacte :
{
  "patient_name": "Prénom Nom fictif africain/français",
  "age": "nombre entre 5 et 85 selon la pathologie",
  "gender": "Masculin ou Féminin",
  "avatar_hint": "male_young ou female_young ou male_old ou female_old ou child_male ou child_female",
  "consultation_reason": "Le motif de consultation du patient en 1-2 phrases, formulé comme le patient le dirait",
  "initial_symptoms": "Description détaillée des symptômes initiaux en 2-3 phrases",
  "diagnosis": "Le diagnostic final (nom médical de la pathologie)",
  "differential_diagnoses": ["diagnostic différentiel 1", "diagnostic différentiel 2"],
  "antecedents_perso": ["antécédent 1", "antécédent 2"],
  "antecedents_familiaux_pere": ["pathologie du père si pertinent"],
  "antecedents_familiaux_mere": ["pathologie de la mère si pertinent"],
  "allergies": ["allergie si pertinent, sinon Néant"],
  "habits": ["habitude 1", "habitude 2"],
  "exams": [
        {"name": "Nom examen pertinent", "result": "Résultat BRUT uniquement (valeurs/unités/seuils ou description objective)", "is_relevant": true},
        {"name": "Nom examen leurre", "result": "Résultat BRUT normal ou incidentel", "is_relevant": false}
  ],
  "treatment": [
    {
      "medication": "Nom du médicament (DCI de préférence)",
      "dosage": "Dose précise (ex: 500mg, 1g, 10mg/kg)",
      "frequency": "Fréquence et voie d'administration (ex: 3 fois/jour per os, 1 injection IV/8h)",
      "duration": "Durée du traitement (ex: 7 jours, 3 semaines, à vie)"
    }
  ],
  "treatment_notes": "Remarques importantes sur la prise en charge : mesures hygiéno-diététiques, surveillance, contre-indications, éducation thérapeutique",
  "prompt_patient": "Instructions pour l'IA-patient : personnalité, manière de parler, détails à révéler progressivement",
  "prompt_tuteur": "Points clés que l'étudiant doit identifier, erreurs fréquentes à surveiller, diagnostics différentiels à éliminer"
}

RÈGLES CRITIQUES POUR LES EXAMENS :
- Inclure exactement ${relevantCount} examens PERTINENTS (liés au diagnostic) avec des résultats anormaux/pathologiques cohérents
- Inclure exactement ${decoyCount} examens LEURRES (sans rapport avec la maladie) avec des résultats normaux ou non pertinents, pour tester l'esprit critique de l'étudiant
- Les examens leurres doivent être des examens réels mais qui n'apportent rien au diagnostic (ex: ionogramme normal dans une angine, bilan thyroïdien normal dans une fracture)
- Mélanger les examens pertinents et leurres dans la liste (ne pas les regrouper)
- Marquer "is_relevant": true pour les examens utiles au diagnostic, et false pour les leurres
- Le champ "result" doit contenir UNIQUEMENT des données brutes (chiffres, unités, intervalles normaux, descriptions d'imagerie)
- Interdiction d'écrire une conclusion ou une interprétation dans "result"
- Interdiction des formulations : "compatible avec", "en faveur de", "suggère", "évoque", "oriente vers"
- Exemple labo attendu: "GB 18.2 G/L (N 4-10), CRP 132 mg/L (N <5)"
- Exemple imagerie attendu: "TDM abdomino-pelvienne: appendice 11 mm, infiltration graisse péri-appendiculaire"
- L'étudiant doit faire lui-même l'interprétation clinique

RÈGLES POUR LES DIAGNOSTICS DIFFÉRENTIELS :
- La pathologie choisie DOIT avoir des symptômes proches d'autres maladies de la même spécialité
- Inclure ${diffDiagCount} diagnostics différentiels qui pourraient être confondus avec le diagnostic final
- Plus la difficulté est élevée, plus les diagnostics différentiels sont proches et les symptômes atypiques/trompeurs
${difficulty >= 3 ? '- À ce niveau de difficulté, les symptômes initiaux doivent orienter d\'abord vers un mauvais diagnostic avant de révéler la vraie pathologie' : ''}
${difficulty >= 4 ? '- Certains résultats d\'examens leurres peuvent être légèrement anormaux (mais sans rapport avec le diagnostic) pour semer davantage le doute' : ''}

RÈGLES POUR LE TRAITEMENT :
- Inclure le traitement de référence complet (médicaments, posologie, dosage, durée)
- Utiliser les DCI (Dénominations Communes Internationales) de préférence
- Adapter les doses à l'âge et au poids du patient
- Inclure les mesures non médicamenteuses dans treatment_notes
- Inclure 1 à 4 médicaments selon la pathologie
- Être précis sur les voies d'administration (PO, IV, IM, SC, etc.)

AUTRES RÈGLES :
- Le cas doit être médicalement réaliste et cohérent
- Les noms de patients doivent être des noms africains ou français réalistes
- Le diagnostic final doit varier d'une génération à l'autre au sein de la même spécialité
- La difficulté doit influencer la facilité du diagnostic:
  - difficulté 1-2: présentation classique, diagnostic relativement direct
  - difficulté 3: présentation partiellement atypique
  - difficulté 4-5: présentation plus trompeuse avec diagnostics différentiels proches
- La cohérence est obligatoire entre âge, genre, avatar_hint, symptômes, examens et traitement
- Tu dois choisir le diagnostic final dans cette liste prioritaire si elle est fournie
- Si un diagnostic final obligatoire est fourni, il doit être utilisé strictement comme diagnostic final
- Réponds UNIQUEMENT avec le JSON, rien d'autre`;

    const userMessage = [
        `Génère un cas clinique en ${specialtyName}, difficulté ${difficulty}/5.`,
        availableTargetDiseases.length > 0
            ? `Liste prioritaire de diagnostics (niveau ${diseaseTier}) : ${availableTargetDiseases.join(' | ')}`
            : 'Aucune liste prioritaire fournie: choisis une pathologie réaliste de cette spécialité.',
        availableAlternativeDiseases.length > 0
            ? `Diagnostics alternatifs possibles pour diversifier : ${availableAlternativeDiseases.join(' | ')}`
            : '',
        excludedDiagnoses.length > 0
            ? `Diagnostics déjà utilisés et strictement interdits pour cette spécialité: ${excludedDiagnoses.join(' | ')}`
            : '',
        forcedDiagnosis ? `DIAGNOSTIC FINAL OBLIGATOIRE (ne pas en choisir un autre): ${forcedDiagnosis}` : '',
        generationSeed ? `Graine de génération unique: ${generationSeed}` : '',
    ].filter(Boolean).join('\n');

    // Try Groq with higher token limit for case generation
    const apiKey = process.env.GROQ_API_KEY;
    if (apiKey) {
        try {
            const response = await axios.post(
                'https://api.groq.com/openai/v1/chat/completions',
                {
                    model: process.env.GROQ_MODEL || 'llama-3.3-70b-versatile',
                    messages: [
                        { role: 'system', content: systemPrompt },
                        { role: 'user', content: userMessage },
                    ],
                    temperature: 0.8,
                    max_tokens: 2500,
                },
                {
                    headers: {
                        'Authorization': `Bearer ${apiKey}`,
                        'Content-Type': 'application/json',
                    },
                    timeout: 30000,
                }
            );
            const reply = response.data?.choices?.[0]?.message?.content;
            if (reply) {
                // Extract JSON from response (handle potential markdown wrapping)
                let jsonStr = reply.trim();
                if (jsonStr.startsWith('```')) {
                    jsonStr = jsonStr.replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
                }
                console.log('✓ Groq case generation received');
                const parsed = sanitizeGeneratedCase(JSON.parse(jsonStr));
                if (forcedDiagnosis) {
                    return {
                        ...parsed,
                        diagnosis: forcedDiagnosis,
                    };
                }
                return parsed;
            }
        } catch (error) {
            console.warn('Groq case generation failed:', error.response?.data?.error?.message || error.message);
        }
    }

    // Fallback: generate a basic case structure coherent with specialty and difficulty.
    const fallbackPool = availableTargetDiseases.length > 0
        ? availableTargetDiseases
        : (availableAlternativeDiseases.length > 0 ? availableAlternativeDiseases : [
        `Pathologie courante en ${specialtyName}`,
        `Pathologie inflammatoire en ${specialtyName}`,
        `Pathologie aiguë en ${specialtyName}`,
    ]);
    const fallbackDiagnosis = fallbackPool[Math.floor(Math.random() * fallbackPool.length)];

    return {
        patient_name: 'Amadou Diallo',
        age: '45',
        gender: 'Masculin',
        avatar_hint: 'male_old',
        consultation_reason: `Je consulte pour des symptômes récents qui s'aggravent progressivement.`,
        initial_symptoms: `Le patient présente des signes cliniques compatibles avec une pathologie de ${specialtyName}.`,
        diagnosis: fallbackDiagnosis,
        antecedents_perso: ['Aucun antécédent particulier'],
        antecedents_familiaux_pere: [],
        antecedents_familiaux_mere: [],
        allergies: ['Néant'],
        habits: ['Non fumeur', 'Pas d\'alcool'],
        exams: [
            { name: 'NFS', result: 'GB 14.2 G/L (N 4-10), Hb 12.6 g/dL (N 13-17), Plaquettes 280 G/L (N 150-400)', is_relevant: true },
            { name: 'CRP', result: 'CRP 98 mg/L (N <5)', is_relevant: true },
            { name: 'TSH', result: 'TSH 2.1 mUI/L (N 0.4-4.0)', is_relevant: false },
        ],
        treatment: [
            { medication: 'À définir', dosage: 'À définir', frequency: 'À définir', duration: 'À définir' },
        ],
        treatment_notes: 'À compléter',
        prompt_patient: '',
        prompt_tuteur: '',
    };
};

// ═══════════════════════════════════════════════════════════
//  AI Course Generation — generates a course from a case
// ═══════════════════════════════════════════════════════════

const generateCourse = async (caseData) => {
    const systemPrompt = `Tu es un enseignant médical expert en pédagogie SVT/médecine. Tu dois produire un cours de haute qualité à partir d'un cas clinique, sans jamais donner la correction explicite du cas.

Tu dois répondre UNIQUEMENT avec un objet JSON valide (sans markdown, sans commentaires, sans backticks) :
{
    "title": "[Pathologie] : Cours SVT médical appliqué",
    "content": "Texte brut structuré avec les 14 sections OBLIGATOIRES ci-dessous, dans cet ordre exact",
    "references": [
        {
            "title": "Titre précis de la ressource",
            "url": "URL réelle, active et directement liée au thème du cas",
            "type": "article|guideline|textbook|video"
        }
    ]
}

RÈGLES OBLIGATOIRES DE CONTENU :
- Langue : français clair, pédagogique, niveau étudiant en santé
- Format : texte brut uniquement (jamais #, *, **, markdown)
- Les titres doivent être exactement numérotés comme ci-dessous, suivis de deux-points
- Le cours explique la maladie et le raisonnement général, sans résoudre le cas clinique réel de l'étudiant
- Interdiction de donner un diagnostic final explicite du cas de session
- Chaque section doit être utile, détaillée, et liée au thème du cas
- Style rédactionnel: paragraphes explicatifs développés, transitions pédagogiques, exemples concrets
- Pour chaque section, rédiger au minimum 2 paragraphes complets (pas des notes brèves)
- Donner des explications causales: "pourquoi", "comment", "quelles conséquences"
- Éviter les listes à puces: privilégier la prose continue, lisible comme un vrai cours

SECTIONS OBLIGATOIRES (ordre strict) :
1. TITRE DU COURS :
2. PROBLEMATIQUE SVT :
3. OBJECTIFS D'APPRENTISSAGE :
4. PREREQUIS :
5. VOCABULAIRE CLE :
6. RAPPELS ANATOMIE ET PHYSIOLOGIE :
7. MECANISME DE LA MALADIE (PHYSIOPATHOLOGIE) :
8. CAUSES ET FACTEURS DE RISQUE :
9. SIGNES CLINIQUES :
10. EXAMENS ET INTERPRETATION GENERALE :
11. PRINCIPES DE PRISE EN CHARGE (SANS RESOUDRE LE CAS) :
12. PREVENTION ET SURVEILLANCE :
13. ERREURS FREQUENTES :

RÈGLES POUR LE CHAMP "references" :
- Fournir 5 à 8 références médicales fiables en bas de la réponse JSON (champ references)
- Les références ne doivent PAS être répétées dans une section du contenu
- 5 à 8 entrées
- Chaque URL doit être cohérente avec la pathologie étudiée

Réponds UNIQUEMENT avec le JSON, rien d'autre.`;

    const caseSummary = `Cas clinique de référence (anonymisé, pour orientation pédagogique) :
- Profil patient : ${caseData.medical_history?.age || '?'} ans, ${caseData.medical_history?.gender || '?'}
- Motif : ${caseData.consultation_reason || 'Non spécifié'}
- Symptômes : ${caseData.initial_symptoms || 'Non spécifié'}
- Examens disponibles : ${(caseData.case_exams || []).map(e => e.name).join(', ') || 'Non spécifié'}
- Antécédents : ${JSON.stringify(caseData.medical_history?.antecedents || {})}

Important : produire un cours de compréhension médicale en lien avec ce contexte.
Le cas clinique doit rester séparé du cours (pas de correction explicite, pas de diagnostic final donné directement).`;

    const apiKey = process.env.GROQ_API_KEY;
    if (apiKey) {
        try {
            const response = await axios.post(
                'https://api.groq.com/openai/v1/chat/completions',
                {
                    model: process.env.GROQ_MODEL || 'llama-3.3-70b-versatile',
                    messages: [
                        { role: 'system', content: systemPrompt },
                        { role: 'user', content: `Génère un cours basé sur ce cas :\n${caseSummary}` },
                    ],
                    temperature: 0.7,
                    max_tokens: 6500,
                },
                {
                    headers: {
                        'Authorization': `Bearer ${apiKey}`,
                        'Content-Type': 'application/json',
                    },
                    timeout: 90000,
                }
            );
            const reply = response.data?.choices?.[0]?.message?.content;
            if (reply) {
                let jsonStr = reply.trim();
                if (jsonStr.startsWith('```')) {
                    jsonStr = jsonStr.replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
                }
                console.log('✓ Groq course generation received');
                return JSON.parse(jsonStr);
            }
        } catch (error) {
            console.warn('Groq course generation failed:', error.response?.data?.error?.message || error.message);
        }
    }

    // Fallback
    return {
        title: `${caseData.logic_medicale || caseData.consultation_reason || 'Pathologie'} : Cours SVT médical appliqué`,
        content: `1. TITRE DU COURS :
${caseData.logic_medicale || caseData.consultation_reason || 'Pathologie'}

2. PROBLEMATIQUE SVT :
    Dans ce cours, l'enjeu est de comprendre comment des perturbations biologiques progressives se traduisent par des manifestations cliniques observables au lit du patient. L'étudiant doit relier les signes fonctionnels, l'examen clinique et les données paracliniques afin de construire un raisonnement médical cohérent.

    La problématique centrale est de distinguer les mécanismes réellement responsables des symptômes de ceux qui ne sont que des facteurs associés. Cette distinction est essentielle pour éviter les erreurs d'interprétation et hiérarchiser correctement les hypothèses diagnostiques.

3. OBJECTIFS D'APPRENTISSAGE :
    À la fin du cours, l'étudiant doit être capable d'expliquer avec précision les mécanismes physiopathologiques qui mènent aux signes cliniques les plus fréquents. Il doit également savoir justifier le lien entre symptôme, hypothèse diagnostique et examen complémentaire à demander.

    L'étudiant doit aussi être capable de prioriser la prise en charge initiale, d'identifier les éléments de gravité et d'argumenter ses choix thérapeutiques de manière structurée, sans se limiter à une récitation de protocoles.

4. PREREQUIS :
    Avant d'aborder ce cours, il est nécessaire de maîtriser les bases anatomiques et physiologiques de l'organe ou du système concerné. Cette base permet de comprendre pourquoi certains symptômes apparaissent et comment ils évoluent dans le temps.

    Une connaissance des examens biologiques et d'imagerie courants est également indispensable. L'étudiant doit savoir interpréter des résultats simples dans leur contexte clinique, plutôt que de les analyser de manière isolée.

5. VOCABULAIRE CLE :
    Les notions de symptôme, de signe clinique, de facteur de risque, de physiopathologie et de diagnostic différentiel constituent le socle du raisonnement. Chaque terme doit être compris non seulement dans sa définition, mais aussi dans son utilité pratique lors d'une consultation.

    Le vocabulaire lié à la prise en charge et à la surveillance permet ensuite d'anticiper l'évolution du patient. Employer correctement ces termes aide à communiquer clairement entre soignants et à sécuriser la décision médicale.

6. RAPPELS ANATOMIE ET PHYSIOLOGIE :
    Le fonctionnement normal des structures anatomiques impliquées doit être rappelé de manière progressive. Ce rappel sert de référence pour reconnaître les déviations pathologiques observées chez le patient.

    La physiologie normale explique la logique des symptômes: lorsqu'un mécanisme est perturbé, une chaîne d'effets apparaît sur l'organisme. Comprendre cette chaîne est indispensable pour éviter une approche purement descriptive.

7. MECANISME DE LA MALADIE (PHYSIOPATHOLOGIE) :
    La maladie se développe selon une cascade physiopathologique où un évènement initial déclenche des réponses inflammatoires, métaboliques ou hémodynamiques. Cette progression explique la chronologie des plaintes du patient et la variabilité de présentation clinique.

    L'analyse mécanistique permet de comprendre pourquoi certains examens deviennent anormaux avant d'autres. Elle justifie aussi la stratégie thérapeutique en ciblant les mécanismes clés plutôt que les manifestations superficielles.

8. CAUSES ET FACTEURS DE RISQUE :
    Les causes doivent être classées selon leur fréquence et leur gravité potentielle. Cette hiérarchisation aide l'étudiant à sécuriser sa démarche en éliminant d'abord les situations menaçantes.

    Les facteurs de risque individuels, familiaux et environnementaux modulent la probabilité de chaque hypothèse. Leur identification précise améliore la pertinence diagnostique et limite les explorations inutiles.

9. SIGNES CLINIQUES :
    Les signes cliniques doivent être lus comme un ensemble dynamique: intensité, durée, facteurs déclenchants et éléments associés. Cette approche donne une valeur diagnostique bien supérieure à une simple liste de symptômes.

    Les signes d'alerte doivent être systématiquement recherchés, car ils conditionnent l'urgence de la prise en charge. Leur absence ou leur présence modifie directement l'orientation clinique et la stratégie d'examens.

10. EXAMENS ET INTERPRETATION GENERALE :
    Les examens complémentaires doivent être demandés pour répondre à une question clinique précise. Un examen est pertinent lorsqu'il permet de confirmer, d'infirmer ou de prioriser une hypothèse déjà argumentée.

    L'interprétation générale repose sur la cohérence entre les résultats et le tableau clinique. Un résultat anormal isolé ne suffit pas à conclure; c'est la convergence des données qui donne de la robustesse au raisonnement.

11. PRINCIPES DE PRISE EN CHARGE (SANS RESOUDRE LE CAS) :
    La prise en charge initiale s'organise autour de trois priorités: stabiliser le patient, traiter le mécanisme principal et prévenir les complications. Cette logique doit rester adaptable au terrain, à la sévérité et aux comorbidités.

    Les options thérapeutiques doivent être justifiées en termes de bénéfice attendu, de risques et de surveillance. Cette justification est essentielle pour former un raisonnement thérapeutique solide, au-delà de l'application mécanique d'un protocole.

12. PREVENTION ET SURVEILLANCE :
    La prévention repose sur l'identification des facteurs modifiables et l'éducation du patient. Une information claire améliore l'adhésion thérapeutique et réduit le risque de récidive ou de décompensation.

    La surveillance doit être planifiée avec des critères cliniques et biologiques précis, ainsi qu'un calendrier de réévaluation. Cette structuration permet de détecter rapidement une aggravation et d'adapter la stratégie de soins.

13. ERREURS FREQUENTES :
    Les erreurs les plus fréquentes incluent la focalisation trop précoce sur une seule hypothèse, la sous-estimation des signes de gravité et l'absence de réévaluation après un premier traitement. Ces erreurs exposent à des retards diagnostiques et à une prise en charge inadaptée.

    Il est également fréquent de surinterpréter un examen isolé sans l'intégrer au contexte clinique global. Une démarche rigoureuse impose de confronter en permanence hypothèses, données nouvelles et évolution du patient.
`,
        references: [
            { title: 'MSD Manuals - Version professionnelle', url: 'https://www.msdmanuals.com/fr/professional', type: 'textbook' },
            { title: 'WHO - Health Topics', url: 'https://www.who.int/health-topics', type: 'guideline' },
            { title: 'HAS - Recommandations', url: 'https://www.has-sante.fr/jcms/fc_2875171/fr/recherche?text=recommandations', type: 'guideline' },
            { title: 'PubMed', url: 'https://pubmed.ncbi.nlm.nih.gov/', type: 'article' },
            { title: 'Vidal - Informations médicales', url: 'https://www.vidal.fr/', type: 'textbook' },
        ],
    };
};

// ═══════════════════════════════════════════════════════════
//  AI Quiz Generation — generates disease-specific MCQ quiz
// ═══════════════════════════════════════════════════════════

const generateQuizFromCase = async (caseData, questionCount = 30) => {
    const safeCount = Math.min(40, Math.max(10, Number(questionCount) || 30));
    const disease = caseData?.disease_id || caseData?.logic_medicale || caseData?.consultation_reason || 'Pathologie médicale';
    const symptomsText = String(caseData?.initial_symptoms || '').trim();
    const motifText = String(caseData?.consultation_reason || '').trim();

    const systemPrompt = `Tu es un enseignant médical expert en évaluation clinique.

Tu dois produire UNIQUEMENT un objet JSON valide (sans markdown, sans texte additionnel):
{
  "title": "Quiz - [Nom de la maladie]",
  "disease": "Nom précis de la maladie",
  "questions": [
    {
      "id": 1,
      "question": "Question clinique claire et précise",
      "options": {
        "A": "Option A",
        "B": "Option B",
        "C": "Option C",
        "D": "Option D"
      },
      "answer": "A",
      "explanation": "Explication courte et pédagogique"
    }
  ]
}

RÈGLES:
- Générer exactement ${safeCount} questions
- Toutes les questions doivent porter sur la maladie: ${disease}
- Niveau étudiant en santé, difficulté progressive
- Une seule bonne réponse parmi A/B/C/D
- Réponses et explications en français
- Questions variées: physiopathologie, clinique, examens, traitement, prévention, pièges
- Interdiction stricte de répéter la même question, même avec reformulation minimale
- Chaque question doit mentionner explicitement la maladie (${disease}) OU un élément direct du contexte clinique
- Ne pas donner de correction hors champ "answer" et "explanation"`;

    const userMessage = `Crée un quiz de ${safeCount} QCM sur la maladie ${disease}, basé sur ce contexte:
Motif: ${caseData?.consultation_reason || 'Non spécifié'}
Symptômes: ${caseData?.initial_symptoms || 'Non spécifié'}
Contexte patient: ${JSON.stringify(caseData?.medical_history || {})}`;

    const normalizeQuestionKey = (value) =>
        String(value || '')
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, ' ')
            .replace(/\bq\s*\d+\b/g, '')
            .trim();

    const buildFallbackQuestions = () => {
        const contextClause = symptomsText
            ? `avec un contexte de symptômes: ${symptomsText}`
            : (motifText ? `avec un motif de consultation: ${motifText}` : 'dans ce contexte clinique');

        const stems = [
            `Pour ${disease}, quel signe clinique est le plus orientant ${contextClause} ?`,
            `Dans ${disease}, quel examen de première intention est le plus pertinent ${contextClause} ?`,
            `Quel mécanisme physiopathologique explique le mieux ${disease} ?`,
            `Face à ${disease}, quelle conduite thérapeutique initiale est la plus adaptée ?`,
            `Quel facteur de risque augmente le plus la probabilité de ${disease} ?`,
            `Quel signe d'alerte impose une réévaluation urgente dans ${disease} ?`,
            `Dans ${disease}, quelle erreur diagnostique faut-il éviter en priorité ?`,
            `Quel élément de l'interrogatoire aide le plus à confirmer ${disease} ?`,
            `Pour ${disease}, quel objectif de suivi est prioritaire après stabilisation ?`,
            `Dans ${disease}, quelle mesure de prévention secondaire est la plus utile ?`,
            `Quel résultat d'examen est le plus compatible avec ${disease} ?`,
            `Dans ${disease}, quel argument oriente vers une forme sévère ?`,
            `Pour ${disease}, quelle stratégie améliore le raisonnement clinique initial ?`,
            `Dans ${disease}, quel élément aide le plus au diagnostic différentiel ?`,
            `Face à ${disease}, quelle attitude envers les examens complémentaires est correcte ?`,
            `Dans ${disease}, quel principe de prise en charge réduit les complications ?`,
            `Quel signe fonctionnel est le plus évocateur de ${disease} ?`,
            `Dans ${disease}, quelle information patient est indispensable au plan de soins ?`,
            `Pour ${disease}, quel piège de communication clinique doit être évité ?`,
            `Dans ${disease}, quelle donnée du contexte patient influence le plus la décision ?`,
            `Quelle priorité thérapeutique est la plus logique pour ${disease} ?`,
            `Dans ${disease}, quel indicateur clinique reflète le mieux l'évolution ?`,
            `Pour ${disease}, quelle démarche d'évaluation initiale est la plus robuste ?`,
            `Dans ${disease}, quel argument soutient la nécessité d'un suivi rapproché ?`,
            `Pour ${disease}, quelle interprétation clinique est la plus prudente ?`,
            `Dans ${disease}, quelle combinaison clinique est la plus évocatrice ?`,
            `Pour ${disease}, quelle erreur de prise en charge expose à une rechute ?`,
            `Dans ${disease}, quel message d'éducation thérapeutique est prioritaire ?`,
            `Pour ${disease}, quel élément justifie une adaptation du traitement ?`,
            `Dans ${disease}, quel critère permet le mieux d'évaluer la réponse au traitement ?`,
            `Pour ${disease}, quelle décision est la plus cohérente en première réévaluation ?`,
            `Dans ${disease}, quelle donnée clinique doit être recontrôlée en priorité ?`,
            `Pour ${disease}, quelle stratégie minimise le risque d'erreur diagnostique ?`,
            `Dans ${disease}, quel argument soutient un raisonnement clinique structuré ?`,
            `Pour ${disease}, quel choix améliore le pronostic à moyen terme ?`,
            `Dans ${disease}, quelle observation est la plus utile pour orienter le suivi ?`,
            `Pour ${disease}, quel point clinique est le plus important à vérifier en premier ?`,
            `Dans ${disease}, quel signe impose de prioriser la sécurité du patient ?`,
            `Pour ${disease}, quelle décision optimise la balance bénéfice-risque ?`,
            `Dans ${disease}, quel élément clinique renforce le diagnostic principal ?`,
        ];

        const wrongSets = [
            ['Ignorer les signes d\'alerte', 'Retarder toute évaluation clinique', 'Décider sans examen clinique'],
            ['Éviter la réévaluation', 'Reporter le suivi systématiquement', 'Négliger le contexte patient'],
            ['Se baser sur une seule donnée isolée', 'Écarter les diagnostics différentiels', 'Prescrire sans justification'],
            ['Uniformiser le traitement sans adaptation', 'Ne pas informer le patient', 'Minimiser les facteurs de risque'],
        ];

        const correctPool = [
            'Corréler signes cliniques, contexte patient et examens ciblés',
            'Prioriser une démarche diagnostique structurée et progressive',
            'Adapter la prise en charge à la sévérité et au profil du patient',
            'Réévaluer régulièrement selon l\'évolution clinique',
        ];

        return Array.from({ length: safeCount }, (_, i) => {
            const stem = stems[i % stems.length];
            const correctText = correctPool[i % correctPool.length];
            const wrong = wrongSets[i % wrongSets.length];
            const letters = ['A', 'B', 'C', 'D'];
            const correctLetter = letters[i % letters.length];
            const ordered = [wrong[0], wrong[1], wrong[2]];

            const options = { A: '', B: '', C: '', D: '' };
            let wrongIndex = 0;
            for (const letter of letters) {
                if (letter === correctLetter) {
                    options[letter] = correctText;
                } else {
                    options[letter] = ordered[wrongIndex] || 'Option non pertinente';
                    wrongIndex += 1;
                }
            }

            return {
                id: i + 1,
                question: stem,
                options,
                answer: correctLetter,
                explanation: `Pour ${disease}, cette option respecte la logique clinique et le contexte du cas.`,
            };
        });
    };

    const apiKey = process.env.GROQ_API_KEY;
    if (apiKey) {
        try {
            const response = await axios.post(
                'https://api.groq.com/openai/v1/chat/completions',
                {
                    model: process.env.GROQ_MODEL || 'llama-3.3-70b-versatile',
                    messages: [
                        { role: 'system', content: systemPrompt },
                        { role: 'user', content: userMessage },
                    ],
                    temperature: 0.5,
                    max_tokens: 7000,
                },
                {
                    headers: {
                        Authorization: `Bearer ${apiKey}`,
                        'Content-Type': 'application/json',
                    },
                    timeout: 90000,
                },
            );

            const reply = response.data?.choices?.[0]?.message?.content;
            if (reply) {
                let jsonStr = reply.trim();
                if (jsonStr.startsWith('```')) {
                    jsonStr = jsonStr.replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
                }
                const parsed = JSON.parse(jsonStr);
                if (Array.isArray(parsed?.questions)) {
                    const unique = new Map();
                    for (const q of parsed.questions) {
                        if (!q || !q.question || !q.options || !q.answer) continue;
                        const key = normalizeQuestionKey(q.question);
                        if (!key || unique.has(key)) continue;
                        unique.set(key, q);
                    }

                    parsed.questions = Array.from(unique.values())
                        .filter((q) => q && q.question && q.options && q.answer)
                        .slice(0, safeCount)
                        .map((q, idx) => ({
                            id: idx + 1,
                            question: String(q.question || '').trim(),
                            options: {
                                A: String(q.options?.A || '').trim(),
                                B: String(q.options?.B || '').trim(),
                                C: String(q.options?.C || '').trim(),
                                D: String(q.options?.D || '').trim(),
                            },
                            answer: String(q.answer || 'A').trim().toUpperCase().slice(0, 1),
                            explanation: String(q.explanation || '').trim(),
                        }));
                }

                if (!Array.isArray(parsed?.questions) || parsed.questions.length < safeCount) {
                    const fallback = buildFallbackQuestions();
                    const existing = Array.isArray(parsed?.questions) ? parsed.questions : [];
                    const existingKeys = new Set(existing.map((q) => normalizeQuestionKey(q.question)));
                    for (const fq of fallback) {
                        const key = normalizeQuestionKey(fq.question);
                        if (existingKeys.has(key)) continue;
                        existing.push(fq);
                        if (existing.length >= safeCount) break;
                    }
                    parsed.questions = existing.slice(0, safeCount).map((q, idx) => ({ ...q, id: idx + 1 }));
                }

                return {
                    title: parsed?.title || `Quiz - ${disease}`,
                    disease: parsed?.disease || disease,
                    questions: parsed?.questions || [],
                };
            }
        } catch (error) {
            console.warn('Groq quiz generation failed:', error.response?.data?.error?.message || error.message);
        }
    }

    const fallbackQuestions = buildFallbackQuestions();

    return {
        title: `Quiz - ${disease}`,
        disease,
        questions: fallbackQuestions,
    };
};

module.exports = {
    generateResponse,
    generatePatientResponse,
    generateCase,
    generateCourse,
    generateQuizFromCase,
};
