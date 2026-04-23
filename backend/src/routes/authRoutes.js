const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const supabase = require('../config/supabase');
const { generateToken, authenticate } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

// POST /api/auth/register
router.post('/register', validate({ body: { email: 'required', password: 'required', full_name: 'required' } }), async (req, res) => {
  const { email, password, full_name, profile_type } = req.body;
  try {
    // Check if user already exists
    const { data: existing } = await supabase.from('users').select('id').eq('email', email).single();
    if (existing) {
      return res.status(409).json({ error: 'Un compte existe déjà avec cet email' });
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 12);

    // Map profile_type
    const profileMap = { 'Étudiant': 'etudiant', 'Médecin': 'medecin', 'Interne': 'interne', 'Autre': 'autre' };
    const mappedProfile = profileMap[profile_type] || profile_type || 'etudiant';

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
      .select('id,email,full_name,profile_type,role,password_hash,created_at')
      .eq('email', email)
      .single();

    // Distinguish DB errors from wrong credentials to avoid misleading 401 messages.
    if (error) {
      return res.status(500).json({ error: `Erreur base de données: ${error.message}` });
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
    return res.status(500).json({ error: e.message });
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
      .single();

    // Distinguish DB errors from wrong credentials to avoid misleading 401 messages.
    if (error) {
      return res.status(500).json({ error: `Erreur base de données: ${error.message}` });
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
    return res.status(500).json({ error: e.message });
  }
});

// GET /api/auth/me — get current user profile
router.get('/me', authenticate, async (req, res) => {
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('id,email,full_name,profile_type,role,phone,institution,specialty,locale,group_name,created_at')
      .eq('id', req.user.id)
      .single();

    if (error || !user) return res.status(404).json({ error: 'Utilisateur non trouvé' });

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
const { full_name, phone, institution, specialty, locale, group_name } = req.body;
  try {
    const update = {};
    if (full_name != null) update.full_name = full_name;
    if (phone != null) update.phone = phone;
    if (institution != null) update.institution = institution;
    if (specialty != null) update.specialty = specialty;
    if (locale != null) update.locale = locale;
    if (group_name != null) update.group_name = group_name;

    const { error } = await supabase.from('users').update(update).eq('id', req.user.id);
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
