const axios = require('axios');
const { resolveAvatarProfile } = require('./avatarVoiceProfile');

let warnedMissingGroqKey = false;
let warnedMissingLlamaLocalKey = false;

// ═══════════════════════════════════════════════════════════
//  DICA CLINIC — LLM Service
//  Providers supported: 1) Groq (cloud) 2) Local Llama (LM Studio)
//  Note: Gemini/Ollama/fallback were removed by request.
// ═══════════════════════════════════════════════════════════

function uniqueStrings(values) {
    const out = [];
    const seen = new Set();
    for (const v of values || []) {
        const s = String(v || '').trim();
        if (!s || seen.has(s)) continue;
        seen.add(s);
        out.push(s);
    }
    return out;
}

function normalizeProviderName(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (!raw) return '';
    if (raw === 'llama' || raw === 'llama-local' || raw === 'lmstudio') return 'llama';
    return raw;
}

function isGroqRequired() {
    const raw = String(process.env.GROQ_REQUIRED || '').trim().toLowerCase();
    return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

function isLlamaRequired() {
    const raw = String(process.env.LLAMA_REQUIRED || process.env.LMSTUDIO_REQUIRED || '').trim().toLowerCase();
    return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

function getPrimaryLlmProvider() {
    if (isGroqRequired()) return 'groq';
    if (isLlamaRequired()) return 'llama';

    const configured = normalizeProviderName(process.env.LLM_PROVIDER || process.env.LLM_PRIMARY || '');
    if (configured === 'groq' || configured === 'llama') return configured;

    // Default: if Groq key exists, prefer Groq; otherwise fall back to local Llama.
    const groqKey = String(process.env.GROQ_API_KEY || '').trim();
    if (groqKey) return 'groq';
    return 'llama';
}

function getOtherProvider(providerName) {
    return providerName === 'groq' ? 'llama' : 'groq';
}

function isProviderRequired(providerName) {
    if (providerName === 'groq') return isGroqRequired();
    if (providerName === 'llama') return isLlamaRequired();
    return false;
}

function getProviderCall(providerName) {
    return providerName === 'groq' ? callGroq : callLlamaLocal;
}

async function callOpenAiCompatible({
    providerLabel,
    apiKey,
    baseURL,
    modelId,
    systemPrompt,
    userMessage,
    options,
}) {
    const key = String(apiKey || '').trim();
    if (!key) return null;

    const resolvedModelId = String(modelId || '').trim();
    if (!resolvedModelId) return null;

    const resolvedBaseURL = String(baseURL || '').trim();

    const temperature = Number.isFinite(Number(options?.temperature)) ? Number(options.temperature) : 0.7;
    const maxOutputTokens = Number.isFinite(Number(options?.maxOutputTokens))
        ? Number(options.maxOutputTokens)
        : (Number.isFinite(Number(options?.max_tokens)) ? Number(options.max_tokens) : 300);
    const timeoutMs = Number.isFinite(Number(options?.timeoutMs)) ? Number(options.timeoutMs) : 20000;

    try {
        const ai = await import('ai');
        const openaiSdk = await import('@ai-sdk/openai');

        const provider = openaiSdk.createOpenAI({
            apiKey: key,
            ...(resolvedBaseURL ? { baseURL: resolvedBaseURL } : {}),
            ...(providerLabel ? { name: providerLabel } : {}),
        });

        const { text } = await ai.generateText({
            model: provider.chat(resolvedModelId),
            system: String(systemPrompt || ''),
            prompt: String(userMessage || ''),
            temperature,
            maxOutputTokens,
            timeout: timeoutMs,
        });

        const out = String(text || '').trim();
        if (!out) return null;
        console.log(`✓ ${providerLabel || 'LLM'} response received`);
        return out;
    } catch (error) {
        const msg = String(error?.message || 'unknown error');
        console.warn(`${providerLabel || 'LLM'} unavailable (${resolvedBaseURL}):`, msg);
        // Store last error reason for better user-facing messages
        callOpenAiCompatible._lastError = `${providerLabel}: ${msg}`;
        return null;
    }
}

async function callGroq(systemPrompt, userMessage, options = {}) {
    const apiKey = String(process.env.GROQ_API_KEY || '').trim();
    if (!apiKey) {
        if (!warnedMissingGroqKey) {
            warnedMissingGroqKey = true;
            console.warn('Groq disabled: missing GROQ_API_KEY in backend/.env');
        }
        return null;
    }

    const baseURL = String(process.env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1').trim();
    const modelId = String(process.env.GROQ_MODEL || 'llama-3.1-8b-instant').trim();

    return callOpenAiCompatible({
        providerLabel: 'Groq',
        apiKey,
        baseURL,
        modelId,
        systemPrompt,
        userMessage,
        options,
    });
}

async function callLlamaLocal(systemPrompt, userMessage, options = {}) {
    // Local Llama via LM Studio OpenAI-compatible server.
    // Accept both new LLAMA_* vars and legacy OPENAI_* vars to avoid breaking existing setups.
    const apiKey = String(process.env.LLAMA_API_KEY || process.env.OPENAI_API_KEY || 'lmstudio').trim();
    const baseURL = String(process.env.LLAMA_BASE_URL || process.env.OPENAI_BASE_URL || 'http://127.0.0.1:1234/v1').trim();
    const modelId = String(process.env.LLAMA_MODEL || process.env.OPENAI_MODEL || '').trim();

    if (!modelId) {
        if (!warnedMissingLlamaLocalKey) {
            warnedMissingLlamaLocalKey = true;
            console.warn('Local Llama disabled: missing LLAMA_MODEL (or OPENAI_MODEL) in backend/.env');
        }
        return null;
    }

    return callOpenAiCompatible({
        providerLabel: 'Llama',
        apiKey,
        baseURL,
        modelId,
        systemPrompt,
        userMessage,
        options,
    });
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

function normalizePatientKnownText(value) {
    let text = String(value || '').replace(/\r/g, '').trim();
    if (!text) return '';

    // Remove typical teacher/medical-summary phrasing that leaks specialty/diagnosis.
    text = text
        .replace(/^\s*(le|la)\s+patient\s+/i, '')
        .replace(/\b(le|la)\s+patient\b/gi, 'je')
        .replace(/\bje\s+pr[eé]sente\b/gi, "j'ai")
        .replace(/\bsignes\s+cliniques\s+compatibles\s+avec\b/gi, 'symptômes')
        .replace(/\bcompatible\s+avec\b/gi, '')
        .replace(/\bpathologie\b/gi, 'problème')
        .replace(/\bdiagnostic\b/gi, 'ce que j\'ai')
        .replace(/\bde\s+(cardiologie|pneumologie|pediatrie|pédiatrie|gynecologie|gynécologie|neurologie|dermatologie|urologie|gastro\s*ent[eé]rologie|nephrologie|néphrologie|endocrinologie|oncologie|hematologie|hématologie|infectiologie)\b/gi, '')
        .replace(/\s{2,}/g, ' ')
        .trim();

    // Ensure first-person tone if the text became fragment-like.
    if (!/\b(je|j')\b/i.test(text) && /^[a-zàâçéèêëîïôûùüÿñæœ]/i.test(text)) {
        text = `je ${text}`;
    }

    // Clean punctuation.
    text = text
        .replace(/\s+([,.;!?])/g, '$1')
        .replace(/\.{3,}/g, '...')
        .trim();

    return text;
}

function looksLikeNonPatientReply(reply) {
    const text = String(reply || '').toLowerCase();
    if (!text.trim()) return true;

    // Strong signals of a clinician-style answer.
    if (/(\ble patient\b|\bpatiente\b|\bsignes cliniques\b|\bcompatible avec\b|\bpathologie\b|\bdiagnostic\b)/i.test(text)) {
        return true;
    }
    // Specialty leakage (should not happen in patient speech).
    if (/(cardiolog|pneumolog|p[eé]diatr|gyn[eé]colog|neurolog|dermatolog|urolog|gastro\s*ent[eé]rolog|n[eé]phrolog|endocrinolog|oncolog|h[eé]matolog|infectiolog)/i.test(text)) {
        return true;
    }
    // Suggesting tests or medical advice.
    if (/(il faudrait|vous devriez|je vous conseille|je recommande|on doit|bilan|\becg\b|\bscanner\b|\birm\b|prise de sang|analyse[s]?|radiographie)/i.test(text)) {
        return true;
    }
    // Must be first-person.
    if (!/(\bje\b|\bj'\b|\bmoi\b|\bmon\b|\bma\b|\bmes\b)/i.test(text)) {
        return true;
    }
    return false;
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

function sanitizeGeneratedCase(payload, options = {}) {
    if (!payload || typeof payload !== 'object') return payload;

    const normalizeTreatmentEntry = (entry) => {
        if (!entry) return null;
        if (typeof entry === 'string') {
            const med = entry.trim();
            if (!med) return null;
            return { medication: med, dosage: '', frequency: '', duration: '' };
        }
        if (typeof entry !== 'object') return null;

        const medication = String(
            entry.medication ||
            entry.medicament ||
            entry.drug ||
            entry.name ||
            entry.dci ||
            entry.DCI ||
            '',
        ).trim();

        const dosage = String(entry.dosage || entry.dose || entry.posologie || entry.dose_mg || '').trim();
        const frequency = String(entry.frequency || entry.frequence || entry.voie || entry.route || '').trim();
        const duration = String(entry.duration || entry.duree || '').trim();

        if (!medication && !dosage && !frequency && !duration) return null;
        return { medication, dosage, frequency, duration };
    };

    const normalizedTreatment = Array.isArray(payload.treatment)
        ? payload.treatment.map(normalizeTreatmentEntry).filter(Boolean)
        : [];

    const normalizedTreatmentNotes = String(
        payload.treatment_notes ||
        payload.treatment_note ||
        payload.treatmentNotes ||
        payload.notes ||
        '',
    ).trim();

    const hinted = inferDefaultsFromHint(payload.avatar_hint);
    const rawGender = normalizeGeneratedGender(payload.gender) || hinted.gender;
    const rawAge = clampGeneratedAge(payload.age) ?? hinted.age;
    const profile = resolveAvatarProfile({
        avatar: payload.avatar || payload.avatar_hint,
        age: rawAge,
        gender: rawGender,
    });

    const extraSeed = String(options.generationSeed || '').trim();
    const seed = `${payload.diagnosis || ''}|${payload.consultation_reason || ''}|${rawAge}|${rawGender}|${extraSeed}`;
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
        treatment: normalizedTreatment,
        treatment_notes: normalizedTreatmentNotes,
    };
}

// ═══════════════════════════════════════════════════════════
//  Main response generator — Groq ↔ Local Llama (LM Studio)
// ═══════════════════════════════════════════════════════════

const generatePatientResponse = async (caseData, question) => {
    // Build a rich system prompt for the LLM
    const patientName = caseData.patient_name || 'un patient';
    const age = caseData.medical_history?.age || '';
    const gender = caseData.medical_history?.gender || '';
    const rawSymptoms = caseData.initial_symptoms || caseData.consultation_reason || '';
    const symptoms = normalizePatientKnownText(rawSymptoms);
    const history = caseData.medical_history || {};
    const basePrompt = String(caseData.prompt_patient || '').trim();

    const consultationReason = normalizePatientKnownText(caseData.consultation_reason || '') || symptoms;

    const antecedentsPerso = JSON.stringify(history.antecedents?.perso || history.antecedents || []);
    const antecedentsFamiliaux = JSON.stringify(history.antecedents?.familiaux || {});
    const habitudes = JSON.stringify(history.habits || []);
    const allergies = JSON.stringify(history.allergies || []);

    const systemPrompt = `Tu es ${patientName}, ${age ? `${age} ans` : 'un adulte'}, ${gender || 'patient'}.
Tu joues le rôle d'un vrai patient dans une simulation médicale pour étudiants en médecine. Tu parles naturellement, avec tes propres mots.

VIE ET SANTÉ (ce que TU ressens et sais en tant que patient) :
- Pourquoi tu es là : ${consultationReason}
- Ce que tu ressens : ${symptoms}
- Tes antécédents personnels (maladies, opérations passées) : ${antecedentsPerso}
- Antécédents familiaux : ${antecedentsFamiliaux}
- Tes habitudes (tabac, alcool, sport…) : ${habitudes}
- Allergies : ${allergies}
${basePrompt ? `\nTon style de personnalité et comportement : ${basePrompt}` : ''}

COMMENT TU DOIS RÉPONDRE :
1. TOUJOURS à la 1ère personne (je, moi, mon, ma). Jamais "le patient".
2. Révèle tes symptômes PROGRESSIVEMENT — seulement si le médecin pose la bonne question. Ne donne pas tout d'un coup.
3. Si on te demande un symptôme que tu n'as pas : "Non, pas du tout" ou "Non, ça non."
4. Si on te demande ton diagnostic ou ce que tu as : "Je ne sais pas, c'est pour ça que je viens vous voir."
5. Interdits absolus : termes médicaux, noms de spécialité, "signes cliniques", "pathologie", "compatible avec".
6. Réponses courtes et naturelles : 1 à 2 phrases maximum (30 mots max).
7. Exprime parfois ton inquiétude, ta douleur, ton hésitation — comme un vrai patient.
8. Réponds toujours en français, langage courant.
9. Ne propose jamais d'examens ni de traitements. Tu es là pour décrire, pas pour soigner.`;

    const userMessage = question || "Bonjour Docteur.";

    const primary = getPrimaryLlmProvider();

    const tryProviderPatient = async (providerName, promptSystem) => {
        const callFn = providerName === 'groq' ? callGroq : callLlamaLocal;
        const reply = await callFn(promptSystem, userMessage, {
            temperature: 0.7,
            max_tokens: 300,
            timeoutMs: 25000,
        });
        if (reply && !looksLikeNonPatientReply(reply)) return reply;
        if (reply) {
            const retry = await callFn(
                `${promptSystem}\n\nIMPORTANT: Ta dernière réponse n'était pas un patient. Reformule STRICTEMENT à la 1ère personne, langage simple, sans diagnostic, sans "le patient" ni spécialité.`,
                userMessage,
                { temperature: 0.4, max_tokens: 120, timeoutMs: 25000 },
            );
            if (retry && !looksLikeNonPatientReply(retry)) return retry;
        }
        return null;
    };

    const first = primary;
    const second = getOtherProvider(primary);

    const firstReply = await tryProviderPatient(first, systemPrompt);
    if (firstReply) return firstReply;
    if (isProviderRequired(first)) throw new Error(`${first} required but unavailable`);

    const secondReply = await tryProviderPatient(second, systemPrompt);
    if (secondReply) return secondReply;
    if (isProviderRequired(second)) throw new Error(`${second} required but unavailable`);

    throw new Error('LLM required but unavailable');
};

// General-purpose text generation (tuteur, indices, etc.)
// Accepts an optional custom systemPrompt; falls back to a structured default.
const generateResponse = async (prompt, customSystemPrompt) => {
    const systemPrompt = customSystemPrompt || `Tu es un tuteur pédagogique médical expert. Tu analyses le raisonnement clinique d'un étudiant en médecine et tu fournis un feedback structuré, bienveillant et rigoureux en français. Tes retours sont détaillés, précis, et toujours liés aux actions concrètes de l'étudiant.`;
    const primary = getPrimaryLlmProvider();

    const firstName = primary;
    const secondName = getOtherProvider(primary);
    const firstCall = getProviderCall(firstName);
    const secondCall = getProviderCall(secondName);

    const first = await firstCall(systemPrompt, prompt, { temperature: 0.65, maxOutputTokens: 900, timeoutMs: 40000 });
    if (first) return first;
    if (isProviderRequired(firstName)) throw new Error(`${firstName} required but unavailable`);

    const second = await secondCall(systemPrompt, prompt, { temperature: 0.65, maxOutputTokens: 900, timeoutMs: 40000 });
    if (second) return second;
    if (isProviderRequired(secondName)) throw new Error(`${secondName} required but unavailable`);

    throw new Error('LLM required but unavailable');
};

// ═══════════════════════════════════════════════════════════
//  AI Case Generation — generates a full clinical case
// ═══════════════════════════════════════════════════════════

const generateCase = async (specialtyName, difficulty, options = {}) => {
    const excludedDiagnoses = Array.isArray(options.excludedDiagnoses) ? options.excludedDiagnoses : [];
    const generationSeed = String(options.generationSeed || '').trim();
    const forcedDiagnosisInput = String(options.forcedDiagnosis || '').trim();
    const diffLabel = ['très facile', 'facile', 'intermédiaire', 'difficile', 'très difficile'][Math.min(difficulty - 1, 4)];

    // 5 saisons par spécialité (s1=très facile → s5=expert), 12+ maladies par saison pour couvrir 10 épisodes sans répétition
    const specialtyDiseaseMatrix = {
        cardiologie: {
            s1: ['Hypertension artérielle essentielle', 'Insuffisance cardiaque gauche décompensée compensée', 'Fibrillation auriculaire de découverte fortuite', 'Péricardite aiguë virale', 'Cardiopathie hypertensive stable', "Angor stable d'effort", 'Bradycardie sinusale symptomatique', 'Valvulopathie mitrale modérée', 'Bloc de branche droit isolé', 'Flutter auriculaire typique', 'Extrasystoles ventriculaires bénignes', 'Syndrome de Raynaud cardiaque'],
            s2: ['Syndrome coronarien aigu sans sus-décalage ST', 'Insuffisance cardiaque biventriculaire', 'Fibrillation auriculaire rapide avec pré-excitation', 'Trouble conductif auriculo-ventriculaire du 2e degré', 'Valvulopathie aortique significative', 'Cardiomyopathie dilatée débutante', 'Tachycardie ventriculaire non soutenue', 'Angor instable de novo', 'Insuffisance mitrale aiguë', 'Hypertension artérielle résistante', 'Thrombose veineuse profonde proximale', 'Embolie pulmonaire intermédiaire à risque'],
            s3: ['Syndrome coronarien aigu avec sus-décalage ST', 'Cardiomyopathie hypertrophique obstructive', 'Rétrécissement aortique serré symptomatique', 'Tachycardie ventriculaire soutenue', 'Endocardite infectieuse subaiguë', 'Myocardite aiguë virale', 'Syndrome de Wolff-Parkinson-White symptomatique', 'Dissection coronaire spontanée', 'Bloc sino-auriculaire avancé', 'Insuffisance tricuspidienne sévère', 'Cardiomyopathie du péripartum', 'Thrombus intraventriculaire gauche'],
            s4: ['Tamponnade péricardique', 'Dissection aortique de type A', 'Choc cardiogénique post-infarctus', 'Endocardite infectieuse compliquée', 'Syndrome de Brugada avec syncope', 'QT long congénital avec torsades de pointe', 'Rupture de pilier mitral post-ischémique', 'Infarctus du ventricule droit', 'Régurgitation aortique aiguë', 'Hypertension pulmonaire sévère', 'Embolie pulmonaire massive avec état de choc', 'Insuffisance cardiaque réfractaire au traitement'],
            s5: ['Dissection aortique de type B compliquée', 'Choc cardiogénique réfractaire aux amines', 'Tachycardie ventriculaire en tempête électrique', 'Myocardite à cellules géantes', 'Cardiomyopathie de Tako-Tsubo avec complications', 'Syndrome coronarien aigu atypique chez le diabétique', 'Atteinte cardiaque sarcoïdosique', 'Vascularite coronaire sur lupus', 'Syndrome de Dressler post-IDM', 'Hypertension artérielle maligne avec atteinte rénale', 'Compression cardiaque extrinsèque tumorale', 'Endocardite marantique paranéoplasique'],
        },
        pneumologie: {
            s1: ['Asthme aigu simple', 'Pneumonie communautaire lobaire', 'Bronchite aiguë infectieuse', 'Pleurésie réactionnelle', 'Exacerbation légère de BPCO', 'Rhinosinusite aiguë compliquée', 'Trachéobronchite bactérienne', 'Laryngite aiguë sous-glottique', 'Pneumonie atypique à mycoplasme', "Coqueluche de l'adulte", 'Épanchement pleural transudatif', 'Pneumothorax spontané primaire minime'],
            s2: ['Asthme sévère réfractaire aux bronchodilatateurs', 'Pneumonie bilatérale sévère', 'Exacerbation aiguë de BPCO modérée', 'Pleurésie purulente empyème', 'Tuberculose pulmonaire active', "Pneumopathie d'inhalation", 'Épanchement pleural malin', 'Sarcoïdose pulmonaire stade II', 'BPCO gold III avec polyglobulie débutante', 'Pneumonie à pneumocoque bactériémique', 'Silicose avec complications', 'Pneumothorax spontané primaire compressif'],
            s3: ['Embolie pulmonaire intermédiaire', 'BPCO avec polyglobulie secondaire sévère', 'Pneumocystose pulmonaire', 'Aspergillose pulmonaire invasive', "Bronchiectasies compliquées d'hémoptysie", 'Hypertension pulmonaire idiopathique', 'Pneumonie communautaire sévère score PSI élevé', 'Fibrose pulmonaire idiopathique en exacerbation', 'Pneumopathie interstitielle non spécifique', 'Cancer bronchique avec atélectasie', 'Pleurésie tuberculeuse', 'Séquelles pulmonaires post-COVID sévères'],
            s4: ['Pneumothorax compressif', 'SDRA débutant', 'Embolie pulmonaire massive avec état de choc', 'Abcès pulmonaire compliqué', 'Hémoptysie massive', 'Vascularite pulmonaire granulomatose de Wegener', "Pneumopathie d'hypersensibilité aiguë", 'Détresse respiratoire aiguë hypoxémiante', 'Lymphangite carcinomateuse', 'Fistule broncho-pleurale', 'Médiastinite infectieuse descendante', 'Chylothorax traumatique'],
            s5: ['SDRA sévère avec défaillance multiviscérale', 'Aspergillose trachéobronchique invasive', 'Hémorragie alvéolaire diffuse sur vascularite ANCA+', 'Compression trachéale tumorale avec stridor', 'Pneumonie nécrosante à Panton-Valentine leucocidine', 'Hypertension pulmonaire sévère en crise', 'Asthme quasi-fatal sous ventilation', 'Bronchiolite oblitérante post-transplantation', 'Embolie pulmonaire récidivante sous anticoagulation', 'Pleuropneumopathie paranéoplasique', 'SDRA sur noyade secondaire', 'Pneumopathie médicamenteuse sévère'],
        },
        pediatrie: {
            s1: ['Otite moyenne aiguë', 'Gastro-entérite aiguë simple', 'Rhinopharyngite fébrile', 'Angine bactérienne à streptocoque', 'Varicelle non compliquée', 'Exanthème subit roséole', 'Impétigo bulleux localisé', 'Conjonctivite purulente', 'Parasitose intestinale giardia', 'Stomatite herpétique', 'Dermatite atopique en poussée', 'Scarlatine classique'],
            s2: ['Bronchiolite modérée du nourrisson', "Pyélonéphrite aiguë de l'enfant", 'Pneumonie franche lobaire pédiatrique', 'Convulsion fébrile simple', 'Purpura rhumatoïde Schönlein-Henoch', 'Syndrome néphrotique à lésions glomérulaires minimes', 'Anémie ferriprive sévère', 'Diabète de type 1 inaugural', 'Appendicite aiguë non compliquée', 'Croup laryngite striduleuse', 'Hypertension intracrânienne bénigne', 'Intoxication médicamenteuse accidentelle'],
            s3: ['Méningite virale enfant', 'Bronchiolite sévère hypoxémiante', 'Invagination intestinale aiguë', 'Leucémie aiguë révélée par pancytopénie', 'Syndrome hémolytique et urémique', 'Kawasaki incomplet', 'Myocardite virale pédiatrique', 'Épilepsie nouvelle avec état de mal partiel', 'Arthrite septique chez le nourrisson', 'Adénophlegmon cervical', 'Hernie inguinale étranglée', 'Pneumopathie à mycobactérie'],
            s4: ['Méningite bactérienne pédiatrique', 'Épiglottite aiguë obstructive', 'Choc septique sur infection néonatale', 'Myocardite fulminante pédiatrique', 'Acidocétose diabétique inaugurale', 'Intussusception compliquée de nécrose', 'Encéphalite auto-immune pédiatrique', 'Syndrome de Reye', 'Purpura fulminans méningococcique', "Torsion de testicule chez l'adolescent", 'Insuffisance rénale aiguë sur SHU', 'Maltraitance avec traumatisme crânien non accidentel'],
            s5: ['Sepsis néonatal tardif', 'Méningite tuberculeuse pédiatrique', 'Syndrome de détresse respiratoire néonatal', 'Encéphalopathie hypoxo-ischémique néonatale', 'Cardiopathie congénitale cyanogène révélée en néonatal', 'Entérocolite ulcéro-nécrosante néonatale', 'Choc septique réfractaire chez le prématuré', 'Leucémie aiguë en choc hyperleukocytaire', 'Malformation artérioveineuse cérébrale rompue', 'Myocardite nécrosante à entérovirus', 'Intoxication grave aux organophosphorés', 'Aplasie médullaire sur anémie de Fanconi'],
        },
        gynecologie: {
            s1: ['Vaginose bactérienne', 'Dysménorrhée primaire', 'Candidose vulvo-vaginale', 'Métrorragies fonctionnelles de la puberté', 'Mastodynie cyclique', 'Bartholinite aiguë', 'Kyste ovarien fonctionnel', 'Endométriose légère avec algies', 'Vulvite irritative', 'Syndrome prémenstruel sévère', 'Infection génitale à chlamydia', 'Leucorrhées inflammatoires récidivantes'],
            s2: ['Maladie inflammatoire pelvienne', 'Grossesse extra-utérine non rompue', 'Fibromyome utérin symptomatique', "Menace d'accouchement prématuré", 'Hyperemesis gravidarum', 'Rupture prématurée des membranes', 'Kyste ovarien compliqué de torsion partielle', 'Endométriose profonde infiltrante', 'Prolapsus génital symptomatique', 'Grossesse intra-utérine avec saignement du premier trimestre', 'Salpingite sub-aiguë', 'Diabète gestationnel mal équilibré'],
            s3: ['Grossesse extra-utérine rompue', 'Hématome rétroplacentaire partiel', 'Placenta praevia avec métrorragies', "Torsion d'annexe", 'Pyosalpinx compliqué', 'Fausse couche hémorragique', 'Cancer du col utérin révélé par hémorragie', 'Aménorrhée secondaire sur insuffisance ovarienne prématurée', 'Pré-éclampsie modérée', 'Ovaire polykystique avec hyperandrogénie sévère', 'Prolapsus avec incarcération', 'Endométrite post-partum'],
            s4: ['Pré-éclampsie sévère', 'Hémorragie du post-partum', "Torsion d'annexe avec nécrose", 'Rupture utérine sur cicatrice', 'Sepsis puerpéral', 'Hématome rétroplacentaire massif', 'CIVD obstétricale', "Cancer de l'ovaire révélé en urgence", 'Kyste dermoïde rompu avec choc chimique', 'Occlusion intestinale sur carcinose péritonéale gynécologique', 'Thrombophlébite septique pelvienne', 'Embolie amniotique'],
            s5: ['Éclampsie avec état de mal épileptique', 'Hémorragie du post-partum réfractaire', 'Choc septique sur endométrite nécrosante', 'SDRA sur embolie amniotique', 'Cancer du col utérin stade IV révélé en urgence', 'Rupture utérine avec mort foetale', 'HELLP syndrome sévère', 'Pancréatite aiguë gestationnelle sévère', 'Tératome ovarien malin en choc', 'Nécrose utérine post-embolisation', 'Choc anaphylactique au latex peropératoire', 'Défaillance multiviscérale sur sepsis obstétrical'],
        },
        neurologie: {
            s1: ['Migraine sans aura', 'Vertige positionnel paroxystique bénin', 'Névralgie faciale essentielle', 'Céphalée de tension chronique', 'Syndrome des jambes sans repos', 'Neuropathie périphérique diabétique débutante', 'Sciatique commune L5-S1', 'Paralysie faciale périphérique de Bell', 'Syncope vagale récidivante', 'Névrite vestibulaire', 'Accident ischémique transitoire isolé', 'Épilepsie bien contrôlée par traitement'],
            s2: ['AVC ischémique sylvien', 'Syndrome méningé viral', 'Épilepsie partielle avec état de mal convulsif', 'Sclérose en plaques première poussée', 'Polyneuropathie inflammatoire démyélinisante', 'Canal carpien sévère', 'Myasthénie gravis débutante', 'Méningoencéphalite virale', 'Hypertension intracrânienne idiopathique', 'Neuropathie optique rétrobulbaire', 'Syndrome de Claude Bernard-Horner', 'AIT carotidien avec sténose serrée'],
            s3: ['AVC ischémique tronculaire', 'Méningite bactérienne adulte', 'Hémorragie intracérébrale hypertensive', 'Syndrome de Guillain-Barré', 'Myasthénie en crise cholinergique', 'Tumeur cérébrale révélée par comitialité', 'Thrombose veineuse cérébrale', 'Encéphalite limbique auto-immune', 'Maladie de Parkinson avec complications', 'Hématome sous-dural chronique', 'Sclérose latérale amyotrophique évoluée', 'Neuropathie optique ischémique antérieure'],
            s4: ["Hémorragie sous-arachnoïdienne par rupture d'anévrisme", 'Encéphalite herpétique', 'État de mal épileptique réfractaire', 'Syndrome de locked-in sur AVC pontique', 'Rupture de malformation artérioveineuse cérébrale', 'Syndrome de Wernicke sur carence en thiamine', 'Méningite à Listeria', 'Méningite tuberculeuse', 'Syndrome malin des neuroleptiques', 'Thrombose du sinus caverneux', 'Hématome extradural traumatique', 'Poliomyélite spinale progressive'],
            s5: ['Hémorragie sous-arachnoïdienne avec vasospasme cérébral', 'Encéphalite auto-immune réfractaire', 'État de mal épileptique super-réfractaire', 'Encéphalomyélite aiguë disséminée', 'Anoxie cérébrale post-arrêt cardiaque', 'Myopathie inflammatoire avec atteinte cardiaque', 'Méningite fongique chez immunodéprimé', 'Maladie de Creutzfeldt-Jakob sporadique', 'Vasospasme cérébral post-hémorragique étendu', 'Leucoencéphalopathie multifocale progressive', 'Démence à corps de Lewy avec complications sévères', 'Syndrome de déafférentation complète'],
        },
        nephrologie: {
            s1: ['Colique néphrétique simple', 'Infection urinaire basse non compliquée', 'Hématurie microscopique isolée', 'Protéinurie légère de découverte fortuite', 'Insuffisance rénale chronique stade 2', 'Lithiase rénale asymptomatique', 'Pyélonéphrite aiguë simple', "Rétention d'urine aiguë sur hypertrophie bénigne", 'Hyponatrémie légère par potomanie', 'Acidose tubulaire rénale type 1', 'Kyste rénal simple', 'Pollakiurie fonctionnelle chronique'],
            s2: ['Pyélonéphrite aiguë compliquée', 'Insuffisance rénale aiguë fonctionnelle', 'Syndrome néphrotique pur à lésions glomérulaires minimes', "Colique néphrétique compliquée d'obstacle", 'Hyperkaliémie modérée sur insuffisance rénale chronique', 'Néphropathie diabétique stade III', 'Hypertension rénovasculaire', 'Glomérulonéphrite aiguë post-infectieuse', 'Polykystose rénale avec complications', 'Nécrose papillaire rénale', 'Rhabdomyolyse traumatique avec insuffisance rénale débutante', 'Acidose métabolique sur insuffisance rénale'],
            s3: ['Syndrome néphrotique impur', 'Insuffisance rénale aiguë organique', 'Glomérulonéphrite rapidement progressive', 'Néphropathie lupique active', 'Crise rénale sclérodermique', 'Amylose rénale révélée', 'Pyélonéphrite emphysémateuse', 'Nécrose corticale bilatérale', 'Obstruction bilatérale des voies urinaires', 'Syndrome de Goodpasture', 'Microangiopathie thrombotique rénale', 'Granulomatose avec polyangéite rénale'],
            s4: ['Hyperkaliémie menaçante sur insuffisance rénale', 'Syndrome hémolytique et urémique atypique', 'Néphropathie interstitielle aiguë médicamenteuse sévère', 'Insuffisance rénale aiguë anurique', 'Sepsis avec atteinte rénale aiguë sévère', 'Crise aiguë de rejet de transplantation rénale', "Thrombose de l'artère rénale", 'Embolie rénale sur fibrillation auriculaire', 'Rhabdomyolyse sévère avec anurie', 'Endocardite avec néphrite focale', 'Hypertension artérielle maligne avec néphropathie', 'Purpura thrombopénique thrombotique'],
            s5: ['Insuffisance rénale terminale avec hypervolémie réfractaire', 'SHU atypique sur mutation du facteur H', 'Vascularite ANCA+ avec hémorragie alvéolaire et néphrite', 'Rejet hyperaigu de greffe rénale', 'Amylose AA diffuse avec insuffisance rénale terminale', 'Hypercalcémie maligne avec insuffisance rénale', 'Syndrome de lyse tumorale avec anurie', "Glomérulonéphrite de l'hépatite C avec cryoglobulinémie", 'Atteinte rénale de la maladie de Fabry', 'Intoxication aiguë aux métaux lourds avec nécrose tubulaire', 'Néphrite interstitielle granulomateuse sur sarcoïdose', 'Néphropathie fibrilleuse'],
        },
        gastroenterologie: {
            s1: ['Gastrite aiguë simple', 'Reflux gastro-oesophagien symptomatique', 'Colique hépatique simple', "Syndrome de l'intestin irritable", 'Constipation chronique fonctionnelle', 'Hémorroïdes internes compliquées', 'Gastro-entérite virale', 'Hernie hiatale symptomatique', 'Dyspepsie fonctionnelle', "Rectorragies d'origine anale", 'Stéatose hépatique non alcoolique', 'Diarrhée post-antibiothérapie'],
            s2: ['Ulcère gastroduodénal hémorragique', 'Cholécystite aiguë lithiasique', 'Hépatite virale aiguë B', 'Maladie de Crohn iléale débutante', 'Rectorragie sur polype colique', 'Pancréatite aiguë biliaire légère', 'Colite infectieuse à Clostridium difficile', 'Ischémie colique modérée', 'Ascite sur cirrhose compensée', 'Hépatite alcoolique aiguë', "Achalasie de l'oesophage", 'Angiodysplasie colique'],
            s3: ["Péritonite par perforation d'ulcère", 'Pancréatite aiguë nécrotique', 'Hémorragie digestive haute massive', 'Colite aiguë grave de Crohn', 'Rupture de varices oesophagiennes', 'Occlusion intestinale aiguë par bride', 'Cholangite aiguë lithiasique', 'Abcès hépatique amibien', 'Thrombose portale aiguë', 'Appendicite aiguë perforée avec péritonite', 'Carcinome hépatocellulaire sur cirrhose', 'Hémorragie digestive basse massive'],
            s4: ['Hépatite fulminante', 'Colite ischémique étendue', 'Syndrome de Budd-Chiari aigu', 'Perforation colique sur diverticulite', 'Volvulus du côlon sigmoïde', 'Pancréatite nécrotique infectée', 'Infarctus mésentérique', 'Encéphalopathie hépatique fulminante', 'Hémorragie sous-capsulaire hépatique', 'Carcinose péritonéale avec occlusion', 'Hémorragie de Mallory-Weiss avec état de choc', 'Fistule entéro-cutanée compliquée'],
            s5: ['Hépatite fulminante avec coma hépatique', 'Infarctus mésentérique étendu avec nécrose', 'SDRA sur pancréatite aiguë sévère', 'Hémorragie digestive massive incontrôlable', "Occlusion de l'intestin grêle avec étranglement", 'Péritonite généralisée post-opératoire', 'CIVD sur hépato-insuffisance', 'Lymphome digestif révélé par perforation', 'Ischémie-reperfusion intestinale étendue', 'Ascite réfractaire avec syndrome hépato-rénal', 'Rupture spontanée de rate sur hémopathie', 'Choc septique sur cholangite biliaire ascendante'],
        },
        endocrinologie: {
            s1: ['Diabète de type 2 découvert', 'Hypothyroïdie fruste', 'Surpoids avec syndrome métabolique', 'Goitre simple euthyroïdien', 'Ostéoporose post-ménopausique débutante', 'Hypovitaminose D avec myalgies', 'Hyperglycémie de stress transitoire', 'Hypercholestérolémie familiale hétérozygote', 'Syndrome des ovaires polykystiques', 'Hypertriglycéridémie sévère', 'Hyperthyroïdie infraclinique', 'Hypoglycémie réactionnelle fonctionnelle'],
            s2: ['Hyperthyroïdie sur maladie de Basedow', 'Diabète de type 1 inaugural sans acidocétose', 'Adénome hypophysaire à prolactine', 'Insuffisance surrénalienne chronique compensée', 'Hyperparathyroïdie primaire avec lithiase', 'Syndrome de Cushing modéré', 'Phéochromocytome découvert fortuitement', 'Acromégalie débutante', 'Hyponatrémie sur SIADH modéré', 'Ostéoporose avec fracture vertébrale', 'Hypothyroïdie grave avec épanchements', 'Diabète MODY 3'],
            s3: ['Acidocétose diabétique inaugurale', 'Crise thyrotoxique débutante', 'Insuffisance surrénalienne aiguë modérée', 'Phéochromocytome en poussée hypertensive', 'Diabète insipide central', 'Hypercalcémie maligne sur hyperparathyroïdie', 'Syndrome de Zollinger-Ellison', 'Hyperaldostéronisme primaire avec hypokaliémie sévère', 'Macroprolactinome compressif', 'Myxoedème sévère', 'Hyponatrémie profonde symptomatique sur SIADH', 'Nécrose hypophysaire syndrome de Sheehan'],
            s4: ['Acidocétose diabétique sévère avec complications', 'Crise thyrotoxique avec défaillance cardiaque', 'Phéochromocytome en crise hypertensive maligne', 'Insuffisance surrénalienne aiguë avec choc', 'Hypocalcémie sévère post-thyroïdectomie avec tétanie', 'Hypercalcémie maligne réfractaire', 'Coma hyperosmolaire diabétique', 'Tempête thyroïdienne post-opératoire', 'Néoplasie endocrinienne multiple de type 1 révélée', 'Hypoglycémie insulinique sévère récidivante sur insulinome', 'Syndrome de Cushing avec choc septique', 'Adénome surrénalien avec défaillance métabolique'],
            s5: ['Coma myxoédémateux', 'Crise addisonnienne avec choc réfractaire', 'SIADH avec oedème cérébral', 'Phéochromocytome malin avec métastases', 'Tempête thyroïdienne sévère avec encéphalopathie', 'Acidocétose diabétique avec défaillance multiviscérale', 'Insulinome malin avec hypoglycémie réfractaire', 'Carcinome surrénalien avec cushing ectopique', 'Hypoparathyroïdie sévère post-chirurgicale', "Diabète lipoatrophique avec résistance extrême à l'insuline", 'Coma hyperosmolaire avec rhabdomyolyse', 'Adénome corticotrope avec sepsis opportuniste'],
        },
    };

    const normalizeSpecialtyKey = (name) =>
        String(name || '')
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .trim();

    // Aliases pour g\u00e9rer les noms de sp\u00e9cialit\u00e9 qui ne correspondent pas exactement aux cl\u00e9s
    const specialtyAliases = {
        'coeur': 'cardiologie',
        'cardio': 'cardiologie',
        'heart': 'cardiologie',
        'cardiac': 'cardiologie',
        'pulmo': 'pneumologie',
        'poumon': 'pneumologie',
        'lung': 'pneumologie',
        'respiratory': 'pneumologie',
        'pediatrie': 'pediatrie',
        'pediat': 'pediatrie',
        'enfant': 'pediatrie',
        'gyneco': 'gynecologie',
        'gynecologie': 'gynecologie',
        'obstetrique': 'gynecologie',
        'neuro': 'neurologie',
        'cerveau': 'neurologie',
        'nephro': 'nephrologie',
        'rein': 'nephrologie',
        'kidney': 'nephrologie',
        'gastro': 'gastroenterologie',
        'digestif': 'gastroenterologie',
        'foie': 'gastroenterologie',
        'endocrino': 'endocrinologie',
        'diabete': 'endocrinologie',
        'thyroide': 'endocrinologie',
    };

    const specialtyKey = normalizeSpecialtyKey(specialtyName);
    // Chercher d'abord dans les aliases, puis par inclusion directe
    const resolvedKey = specialtyAliases[specialtyKey]
        || Object.entries(specialtyAliases).find(([alias]) => specialtyKey.includes(alias))?.[1]
        || null;
    const matchedKey = resolvedKey
        || Object.keys(specialtyDiseaseMatrix).find((k) => specialtyKey.includes(k))
        || null;
    const diseasePool = matchedKey ? specialtyDiseaseMatrix[matchedKey] : null;

    // Saison = Difficulté (1 étoile → s1, ..., 5 étoiles → s5)
    const tierKeys = ['s1', 's2', 's3', 's4', 's5'];
    const diseaseTier = tierKeys[Math.min(difficulty - 1, 4)];
    const targetDiseases = diseasePool ? (diseasePool[diseaseTier] || []) : [];
    const alternativeDiseases = diseasePool
        ? tierKeys.flatMap((k) => k !== diseaseTier ? (diseasePool[k] || []) : []).filter((d) => !targetDiseases.includes(d))
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

STRUCTURE SAISON / ÉPISODE :
- Ce cas appartient à la SAISON ${difficulty} de la spécialité ${specialtyName} (difficulté ${diffLabel})
- Chaque saison contient 10 épisodes, chacun avec UNE pathologie distincte
- Les 10 pathologies d'une même saison doivent couvrir des mécanismes différents (pas deux insuffisances cardiaques, pas deux pneumonies)
- Varier systématiquement : terrain du patient (âge, sexe, comorbidités), mode de révélation, symptôme principal
- Chaque épisode doit être reconnaissable comme un cas clinique UNIQUE et autonome

RÈGLES DE DIVERSITÉ STRICTES :
- Ne jamais reprendre le même mécanisme pathologique principal qu'un cas déjà exclu
- Changer le profil démographique à chaque génération (vieux/jeune, homme/femme, comorbide/sain)
- Le motif de consultation doit être formulé différemment même pour des pathologies proches
- Privilégier des présentations cliniques variées : urgence vs chronique, typique vs atypique selon la difficulté

AUTRES RÈGLES :
- Le cas doit être médicalement réaliste et cohérent
- Les noms de patients doivent être des noms africains ou français réalistes
- La difficulté doit influencer la facilité du diagnostic:
  - difficulté 1-2 (saison 1-2): présentation classique, diagnostic relativement direct
  - difficulté 3 (saison 3): présentation partiellement atypique
  - difficulté 4-5 (saisons 4-5): présentation trompeuse, diagnostics différentiels proches, symptômes atypiques
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

    const primary = getPrimaryLlmProvider();
    const providerOrder = uniqueStrings([primary, getOtherProvider(primary)]);
    const providerOptions = {
        temperature: 0.8,
        maxOutputTokens: 2500,
        timeoutMs: 60000,
    };

    const tryParseCaseJson = (raw) => {
        let jsonStr = String(raw || '').trim();
        if (!jsonStr) return null;
        if (jsonStr.startsWith('```')) {
            jsonStr = jsonStr.replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
        }
        return sanitizeGeneratedCase(JSON.parse(jsonStr), { generationSeed });
    };

    for (const providerName of providerOrder) {
        const callFn = getProviderCall(providerName);
        const reply = await callFn(systemPrompt, userMessage, providerOptions);
        if (!reply) {
            if (isProviderRequired(providerName)) throw new Error(`${providerName} required but unavailable`);
            continue;
        }

        try {
            const parsed = tryParseCaseJson(reply);
            if (!parsed) continue;
            if (forcedDiagnosis) {
                return {
                    ...parsed,
                    diagnosis: forcedDiagnosis,
                };
            }
            return parsed;
        } catch (error) {
            console.warn(`${providerName} case generation parse failed:`, error.message);
        }
    }

    throw new Error('LLM required but unavailable');
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

    const primary = getPrimaryLlmProvider();
    const providerOrder = uniqueStrings([primary, getOtherProvider(primary)]);
    const userMessage = `Génère un cours basé sur ce cas :\n${caseSummary}`;

    const tryParseCourseJson = (raw) => {
        let jsonStr = String(raw || '').trim();
        if (!jsonStr) return null;
        if (jsonStr.startsWith('```')) {
            jsonStr = jsonStr.replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
        }
        return JSON.parse(jsonStr);
    };

    for (const providerName of providerOrder) {
        const callFn = getProviderCall(providerName);
        const reply = await callFn(systemPrompt, userMessage, {
            temperature: 0.7,
            maxOutputTokens: 6500,
            timeoutMs: 90000,
        });
        if (!reply) {
            if (isProviderRequired(providerName)) throw new Error(`${providerName} required but unavailable`);
            continue;
        }
        try {
            const parsed = tryParseCourseJson(reply);
            if (parsed) return parsed;
        } catch (error) {
            console.warn(`${providerName} course generation parse failed:`, error.message);
        }
    }

    throw new Error('LLM required but unavailable');

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
    // Product rule: always generate exactly 30 questions.
    const safeCount = 30;
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

    const primary = getPrimaryLlmProvider();
    const providerOrder = uniqueStrings([primary, getOtherProvider(primary)]);

    const parseQuizJson = (raw) => {
        let jsonStr = String(raw || '').trim();
        if (!jsonStr) return null;
        if (jsonStr.startsWith('```')) {
            jsonStr = jsonStr.replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '');
        }
        return JSON.parse(jsonStr);
    };

    const enrichAndFixQuiz = (parsed) => {
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
    };

    for (const providerName of providerOrder) {
        const callFn = getProviderCall(providerName);
        const reply = await callFn(systemPrompt, userMessage, {
            temperature: 0.5,
            maxOutputTokens: 7000,
            timeoutMs: 90000,
        });
        if (!reply) {
            if (isProviderRequired(providerName)) throw new Error(`${providerName} required but unavailable`);
            continue;
        }
        try {
            const parsed = parseQuizJson(reply);
            if (!parsed) continue;
            console.log(`✓ ${providerName} quiz generation received`);
            return enrichAndFixQuiz(parsed);
        } catch (error) {
            console.warn(`${providerName} quiz generation parse failed:`, error.message);
        }
    }

    throw new Error('LLM required but unavailable');

    // No fallback: only Groq/Llama are allowed.
};

module.exports = {
    generateResponse,
    generatePatientResponse,
    generateCase,
    generateCourse,
    generateQuizFromCase,
};
