const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const supabase = require('../config/supabase');
const { generateToken, authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const PURCHASES_FILE = path.join(__dirname, '../../data/purchases.json');

const isDev = process.env.NODE_ENV !== 'production';

const formatUnexpectedRuntimeError = (error) => {
  const message = String(error?.message || error || 'unknown error');
  const causeCode = String(error?.cause?.code || '').trim().toUpperCase();
  const causeMessage = String(error?.cause?.message || '').trim();

  // When Supabase is unreachable (DNS, offline), supabase-js often throws TypeError('fetch failed').
  if (/fetch failed/i.test(message) || causeCode === 'ENOTFOUND' || causeCode === 'EAI_AGAIN') {
    return {
      httpStatus: 503,
      publicMessage: 'Impossible de joindre Supabase. Vérifiez SUPABASE_URL (projet Supabase), votre connexion Internet et le DNS.',
      debug: { message, causeCode: causeCode || undefined, causeMessage: causeMessage || undefined },
    };
  }

  return {
    httpStatus: 500,
    publicMessage: isDev ? message : 'Erreur serveur',
    debug: { message, causeCode: causeCode || undefined, causeMessage: causeMessage || undefined },
  };
};

const formatDbError = (error) => {
  if (!error) return null;
  const message = String(error.message || error);

  // Network/DNS issues reaching Supabase
  if (/fetch failed/i.test(message) || /getaddrinfo\s+enotfound/i.test(message) || /eai_again/i.test(message)) {
    return {
      httpStatus: 503,
      publicMessage: 'Impossible de joindre Supabase. Vérifiez SUPABASE_URL (projet Supabase), votre connexion Internet et le DNS.',
      debug: message,
    };
  }

  // Common schema drift issues when the DB wasn't migrated to v2.
  if (/column .*password_hash/i.test(message) || /password_hash.*does not exist/i.test(message)) {
    return {
      httpStatus: 500,
      publicMessage: 'Base de données non migrée: colonne password_hash manquante. Exécutez backend/supabase_schema_v2.sql dans Supabase.',
      debug: message,
    };
  }
  if (/column .*role/i.test(message) || /role.*does not exist/i.test(message)) {
    return {
      httpStatus: 500,
      publicMessage: 'Base de données non migrée: colonne role manquante. Exécutez backend/supabase_schema_v2.sql dans Supabase.',
      debug: message,
    };
  }

  return {
    httpStatus: 500,
    publicMessage: isDev ? message : 'Erreur base de données',
    debug: message,
  };
};

// POST /api/auth/register
router.post('/register', validate({ body: { email: 'required', password: 'required', full_name: 'required' } }), async (req, res) => {
  const { email, password, full_name, profile_type } = req.body;
  try {
    // Check if user already exists
    const { data: existing } = await supabase.from('users').select('id').eq('email', email).maybeSingle();
    if (existing) {
      return res.status(409).json({ error: 'Un compte existe déjà avec cet email' });
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 12);

    // Map profile_type to DB-allowed values: etudiant, medecin, interne, autre
    const profileMap = {
      'Étudiant': 'etudiant',
      'Étudiant en médecine': 'etudiant',
      'etudiant en medecine': 'etudiant',
      'Medecin': 'medecin',
      'Médecin': 'medecin',
      'Interne': 'interne',
      'Joueur': 'autre',
      'joueur': 'autre',
    };
    const mappedProfile = profileMap[profile_type] || (
      ['etudiant','medecin','interne','autre'].includes(profile_type) ? profile_type : 'etudiant'
    );
    const allowedProfiles = new Set(['etudiant', 'medecin', 'interne', 'autre']);
    if (!allowedProfiles.has(mappedProfile)) {
      return res.status(400).json({ error: 'Type de profil invalide' });
    }

    // Insert user
    const { data: user, error } = await supabase
      .from('users')
      .insert([{
        email,
        password_hash,
        full_name,
        profile_type: mappedProfile,
        origin: 'mobile',
        role: 'student',
      }])
      .select('id,email,full_name,profile_type,role,created_at')
      .single();

    if (error) return res.status(500).json({ error: error.message });

    // Initialize XP
    await supabase.from('user_xp').insert([{ user_id: user.id, xp: 0, level: 1 }]);

    // Give 5 initial hints to new user
    try {
      let allPurchases = {};
      if (fs.existsSync(PURCHASES_FILE)) {
        allPurchases = JSON.parse(fs.readFileSync(PURCHASES_FILE, 'utf8'));
      }
      allPurchases[user.id] = ['hint_initial_5'];
      fs.mkdirSync(path.dirname(PURCHASES_FILE), { recursive: true });
      fs.writeFileSync(PURCHASES_FILE, JSON.stringify(allPurchases, null, 2));
    } catch (_) {}

    const token = generateToken(user);
    return res.status(201).json({ token, user });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// POST /api/auth/login
router.post('/login', validate({ body: { email: 'required', password: 'required' } }), async (req, res) => {
  const { email, password } = req.body;
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('id,email,full_name,profile_type,role,password_hash,locale,created_at')
      .eq('email', email)
      .maybeSingle();

    // Distinguish DB errors from wrong credentials to avoid misleading 401 messages.
    if (error) {
      const formatted = formatDbError(error);
      return res.status(formatted.httpStatus).json({ error: formatted.publicMessage, debug: isDev ? formatted.debug : undefined });
    }

    if (!user) {
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

    if (!user.password_hash) {
      return res.status(401).json({ error: 'Compte non configuré — veuillez vous inscrire' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

    // Don't send password_hash to client
    const { password_hash, ...safeUser } = user;
    const token = generateToken(safeUser);
    return res.json({ token, user: safeUser });
  } catch (e) {
    const formatted = formatUnexpectedRuntimeError(e);
    return res.status(formatted.httpStatus).json({ error: formatted.publicMessage, debug: isDev ? formatted.debug : undefined });
  }
});

// POST /api/auth/login-admin (for web admin panel)
router.post('/login-admin', validate({ body: { email: 'required', password: 'required' } }), async (req, res) => {
  const { email, password } = req.body;
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('id,email,full_name,profile_type,role,password_hash,created_at')
      .eq('email', email)
      .maybeSingle();

    // Distinguish DB errors from wrong credentials to avoid misleading 401 messages.
    if (error) {
      const formatted = formatDbError(error);
      return res.status(formatted.httpStatus).json({ error: formatted.publicMessage, debug: isDev ? formatted.debug : undefined });
    }

    if (!user) {
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

    if (!user.role || (user.role !== 'admin' && user.role !== 'teacher')) {
      return res.status(403).json({ error: 'Accès réservé aux administrateurs' });
    }

    if (!user.password_hash) {
      return res.status(401).json({ error: 'Compte non configuré' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    }

    const { password_hash, ...safeUser } = user;
    const token = generateToken(safeUser);
    return res.json({ token, user: safeUser });
  } catch (e) {
    const formatted = formatUnexpectedRuntimeError(e);
    return res.status(formatted.httpStatus).json({ error: formatted.publicMessage, debug: isDev ? formatted.debug : undefined });
  }
});

// GET /api/auth/me — get current user profile
router.get('/me', authenticate, async (req, res) => {
  try {
    const { data: user, error } = await supabase
      .from('users')
      // NOTE: keep this select aligned with backend/supabase_schema_v2.sql.
      .select('id,email,full_name,profile_type,role,phone,institution,specialty,locale,created_at')
      .eq('id', req.user.id)
      .single();

    if (error) {
      const formatted = formatDbError(error);
      return res.status(formatted.httpStatus).json({ error: formatted.publicMessage, debug: isDev ? formatted.debug : undefined });
    }
    if (!user) return res.status(404).json({ error: 'Utilisateur non trouvé' });

    // Get XP
    const { data: xp } = await supabase.from('user_xp').select('xp,level').eq('user_id', user.id).single();
    
    // Get badges
    const { data: badges } = await supabase
      .from('user_badges')
      .select('earned_at,badges(id,name,description,icon)')
      .eq('user_id', user.id);

    return res.json({ user: { ...user, xp: xp?.xp || 0, level: xp?.level || 1, badges: badges || [] } });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// POST /api/auth/social — Google / Apple social login
// Supports both: (1) real OAuth via Supabase Auth token, (2) fallback email-based
router.post('/social', async (req, res) => {
  const { provider, email, full_name, supabase_access_token } = req.body;

  try {
    let userEmail = email;
    let displayName = full_name;

    // If a real Supabase Auth token is provided, verify it
    if (supabase_access_token) {
      const { data: authUser, error: authErr } = await supabase.auth.getUser(supabase_access_token);
      if (authErr || !authUser?.user) {
        return res.status(401).json({ error: 'Token OAuth invalide' });
      }
      userEmail = authUser.user.email;
      displayName = authUser.user.user_metadata?.full_name || authUser.user.user_metadata?.name || displayName || userEmail.split('@')[0];
    }

    if (!userEmail) return res.status(400).json({ error: 'email required' });

    // Check if user exists in our users table
    const { data: existing } = await supabase.from('users').select('id,email,full_name,profile_type,role,created_at').eq('email', userEmail).single();
    if (existing) {
      const token = generateToken(existing);
      return res.json({ token, user: existing, isNew: false });
    }
    // Auto-create account
    const name = displayName || userEmail.split('@')[0];
    const { data: user, error } = await supabase
      .from('users')
      .insert([{
        email: userEmail,
        password_hash: null,
        full_name: name,
        profile_type: 'etudiant',
        origin: provider || 'social',
        role: 'student',
      }])
      .select('id,email,full_name,profile_type,role,created_at')
      .single();
    if (error) return res.status(500).json({ error: error.message });
    await supabase.from('user_xp').insert([{ user_id: user.id, xp: 0, level: 1 }]);
    const token = generateToken(user);
    return res.status(201).json({ token, user, isNew: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

// PATCH /api/auth/me — update profile
router.patch('/me', authenticate, async (req, res) => {
  const { full_name, phone, institution, specialty, locale } = req.body;
  try {
    const update = {};
    if (full_name != null) update.full_name = full_name;
    if (phone != null) update.phone = phone;
    if (institution != null) update.institution = institution;
    if (specialty != null) update.specialty = specialty;
    if (locale != null) update.locale = locale;

    const { error } = await supabase.from('users').update(update).eq('id', req.user.id);
    if (error) {
      const formatted = formatDbError(error);
      return res.status(formatted.httpStatus).json({ error: formatted.publicMessage, debug: isDev ? formatted.debug : undefined });
    }
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
