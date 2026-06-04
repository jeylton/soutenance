/**
 * Clear clinical cases and published quizzes only.
 * - Deletes case_exams then cases.
 * - Resets data/published_quizzes.json to [].
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = supabaseUrl && serviceRoleKey
  ? createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } })
  : null;

async function clearCasesAndQuizzes() {
  console.log('Clearing clinical cases and published quizzes...');

  const quizzesPath = path.join(__dirname, '..', 'data', 'published_quizzes.json');
  try {
    fs.writeFileSync(quizzesPath, '[]', 'utf8');
    console.log('published_quizzes.json reset to []');
  } catch (e) {
    console.error('published_quizzes.json reset error:', e.message);
  }

  if (!supabase) {
    console.log('⚠ Supabase credentials missing; cannot delete cases/case_exams.');
    console.log('   Create backend/.env with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.');
    console.log('Done (local-only).');
    return;
  }

  const { count: examCount, error: examError } = await supabase
    .from('case_exams')
    .delete({ count: 'exact' })
    .neq('id', 0);
  if (examError) {
    console.error('case_exams delete error:', examError.message);
  } else {
    console.log(`case_exams deleted: ${examCount || 0}`);
  }

  const { count: caseCount, error: caseError } = await supabase
    .from('cases')
    .delete({ count: 'exact' })
    .neq('id', 0);
  if (caseError) {
    console.error('cases delete error:', caseError.message);
  } else {
    console.log(`cases deleted: ${caseCount || 0}`);
  }

  console.log('Done.');
}

clearCasesAndQuizzes().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
