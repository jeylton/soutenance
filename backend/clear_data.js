/**
 * Script to clear all test data from Supabase
 * Keeps: admin user, specialties, badges definitions, app_settings
 * Deletes: courses, cases, case_exams, sessions, chat_messages, notifications,
 *          user_xp, user_badges, exam_assignments, session_annotations, student users
 */
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function clearAll() {
  console.log('🗑️  Suppression de toutes les données de test...\n');

  // Order matters due to foreign keys — delete children first

  // 1. Chat messages (depends on sessions)
  const r1 = await supabase.from('chat_messages').delete().neq('id', 0);
  console.log('  ✓ chat_messages:', r1.error ? r1.error.message : 'vidé');

  // 2. Session annotations (depends on sessions)
  const r2 = await supabase.from('session_annotations').delete().neq('id', 0);
  console.log('  ✓ session_annotations:', r2.error ? r2.error.message : 'vidé');

  // 3. Sessions (depends on users, cases)
  const r3 = await supabase.from('sessions').delete().neq('id', 0);
  console.log('  ✓ sessions:', r3.error ? r3.error.message : 'vidé');

  // 4. Exam assignments (depends on cases)
  const r4 = await supabase.from('exam_assignments').delete().neq('id', 0);
  console.log('  ✓ exam_assignments:', r4.error ? r4.error.message : 'vidé');

  // 5. Courses (depends on cases, specialties)
  const r5 = await supabase.from('courses').delete().neq('id', 0);
  console.log('  ✓ courses:', r5.error ? r5.error.message : 'vidé');

  // 6. Case exams (depends on cases)
  const r6 = await supabase.from('case_exams').delete().neq('id', 0);
  console.log('  ✓ case_exams:', r6.error ? r6.error.message : 'vidé');

  // 7. Cases
  const r7 = await supabase.from('cases').delete().neq('id', 0);
  console.log('  ✓ cases:', r7.error ? r7.error.message : 'vidé');

  // 8. Notifications
  const r8 = await supabase.from('notifications').delete().neq('id', 0);
  console.log('  ✓ notifications:', r8.error ? r8.error.message : 'vidé');

  // 9. User badges (depends on users, badges)
  const r9 = await supabase.from('user_badges').delete().neq('id', 0);
  console.log('  ✓ user_badges:', r9.error ? r9.error.message : 'vidé');

  // 10. User XP
  const r10 = await supabase.from('user_xp').delete().neq('id', 0);
  console.log('  ✓ user_xp:', r10.error ? r10.error.message : 'vidé');

  // 11. Delete non-admin users (mobile users / students)
  const r11 = await supabase.from('users').delete().neq('role', 'admin');
  console.log('  ✓ users (non-admin):', r11.error ? r11.error.message : 'vidé');

  // 12. Clear purchases file
  const fs = require('fs');
  const path = require('path');
  const purchasesPath = path.join(__dirname, 'data', 'purchases.json');
  fs.writeFileSync(purchasesPath, '{}', 'utf-8');
  console.log('  ✓ purchases.json: vidé');

  console.log('\n✅ Toutes les données de test ont été supprimées !');
  console.log('   Conservés: compte admin, spécialités, badges, paramètres app');
}

clearAll().catch(err => {
  console.error('❌ Erreur:', err.message);
  process.exit(1);
});
