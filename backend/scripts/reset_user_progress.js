/**
 * Réinitialise la progression d'un utilisateur :
 * - Supprime ses sessions + chat_messages
 * - Remet son XP à 0, level à 1
 * - Supprime ses badges
 * - Supprime ses achats en boutique (hints, avatars)
 *
 * Usage :
 *   node scripts/reset_user_progress.js --email user@exemple.com
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { createClient } = require('@supabase/supabase-js');

function getEmail() {
  const idx = process.argv.indexOf('--email');
  if (idx !== -1 && process.argv[idx + 1]) return process.argv[idx + 1].trim().toLowerCase();
  return null;
}

async function main() {
  const email = getEmail();
  if (!email) {
    console.error('Usage: node scripts/reset_user_progress.js --email <email>');
    process.exit(1);
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY manquants dans .env');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1) Trouver l'utilisateur
  const { data: user, error: userErr } = await supabase
    .from('users')
    .select('id,email,full_name')
    .eq('email', email)
    .maybeSingle();

  if (userErr) { console.error('Erreur DB:', userErr.message); process.exit(1); }
  if (!user) { console.error(`Utilisateur introuvable : ${email}`); process.exit(1); }

  console.log(`\nRéinitialisation de : ${user.full_name} (${user.email})`);
  const userId = user.id;

  // 2) Supprimer chat_messages via sessions
  const { data: sessions } = await supabase
    .from('sessions')
    .select('id')
    .eq('user_id', userId);

  const sessionIds = (sessions || []).map(s => s.id);

  if (sessionIds.length > 0) {
    await supabase.from('chat_messages').delete().in('session_id', sessionIds);
    console.log(`  ✓ chat_messages supprimés (${sessionIds.length} sessions)`);

    await supabase.from('session_annotations').delete().in('session_id', sessionIds);
    console.log(`  ✓ session_annotations supprimées`);

    await supabase.from('sessions').delete().in('id', sessionIds);
    console.log(`  ✓ sessions supprimées (${sessionIds.length})`);
  } else {
    console.log('  ✓ aucune session trouvée');
  }

  // 3) Reset XP
  const { error: xpErr } = await supabase
    .from('user_xp')
    .upsert({ user_id: userId, xp: 0, level: 1 }, { onConflict: 'user_id' });
  if (xpErr) console.error('  ✗ XP reset error:', xpErr.message);
  else console.log('  ✓ XP remis à 0, level 1');

  // 4) Supprimer badges
  await supabase.from('user_badges').delete().eq('user_id', userId);
  console.log('  ✓ badges supprimés');

  // 5) Reset achats boutique (Supabase)
  const { error: purchErr } = await supabase.from('user_purchases_store').delete().eq('user_id', String(userId));
  if (purchErr) console.error('  ✗ erreur suppression achats:', purchErr.message);
  else console.log('  ✓ achats boutique supprimés');

  // 6) Reset quiz attempts (Supabase)
  const { error: quizErr } = await supabase.from('user_quiz_store').delete().eq('user_id', String(userId));
  if (quizErr) console.error('  ✗ erreur suppression quiz attempts:', quizErr.message);
  else console.log('  ✓ tentatives quiz supprimées');

  console.log('\n✅ Compte réinitialisé avec succès.');
}

main().catch(err => {
  console.error('Erreur fatale:', err?.message || String(err));
  process.exit(1);
});
