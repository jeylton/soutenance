/**
 * Supprime complètement un compte utilisateur et toutes ses données.
 * Usage : node scripts/delete_user.js --email user@exemple.com
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
    console.error('Usage: node scripts/delete_user.js --email <email>');
    process.exit(1);
  }

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: user, error: userErr } = await supabase
    .from('users')
    .select('id,email,full_name')
    .eq('email', email)
    .maybeSingle();

  if (userErr) { console.error('Erreur DB:', userErr.message); process.exit(1); }
  if (!user) { console.error(`Utilisateur introuvable : ${email}`); process.exit(0); }

  console.log(`\nSuppression de : ${user.full_name} (${user.email})`);
  const userId = user.id;

  const { data: sessions } = await supabase.from('sessions').select('id').eq('user_id', userId);
  const sessionIds = (sessions || []).map(s => s.id);

  if (sessionIds.length > 0) {
    await supabase.from('chat_messages').delete().in('session_id', sessionIds);
    await supabase.from('session_annotations').delete().in('session_id', sessionIds);
    await supabase.from('sessions').delete().in('id', sessionIds);
    console.log(`  ✓ sessions + messages supprimés (${sessionIds.length})`);
  }

  await supabase.from('user_xp').delete().eq('user_id', userId);
  await supabase.from('user_badges').delete().eq('user_id', userId);
  await supabase.from('users').delete().eq('id', userId);

  console.log('  ✓ XP, badges, compte supprimés');
  console.log('\n✅ Compte supprimé. Cet email peut maintenant être utilisé pour créer un nouveau compte.');
}

main().catch(err => {
  console.error('Erreur fatale:', err?.message || String(err));
  process.exit(1);
});
