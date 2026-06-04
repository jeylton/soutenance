/**
 * Reset published content for a clean demo/dev baseline.
 *
 * What it does (default):
 * - Clears backend/data/published_quizzes.json (sets to [])
 * - Clears backend/data/quiz_attempts.json (sets to {})
 * - Deletes published courses (Supabase table: courses where status='published')
 * - Deletes active cases (Supabase table: cases where status='active')
 *   and their related case_exams rows.
 *
 * Safety:
 * - This script is destructive to content. Use only on DEV / demo projects.
 *
 * Usage:
 *   node scripts/reset_published_content.js
 *   node scripts/reset_published_content.js --include-drafts
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

function hasFlag(name) {
  return process.argv.slice(2).includes(`--${name}`);
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2), 'utf8');
}

async function main() {
  const includeDrafts = hasFlag('include-drafts');

  const publishedQuizzesPath = path.join(__dirname, '..', 'data', 'published_quizzes.json');
  const quizAttemptsPath = path.join(__dirname, '..', 'data', 'quiz_attempts.json');

  console.log('🧹 Reset content (published)');
  console.log('   - includeDrafts:', includeDrafts);

  // 1) Clear JSON stores used by quiz system
  writeJson(publishedQuizzesPath, []);
  console.log('  ✓ cleared published_quizzes.json');

  writeJson(quizAttemptsPath, {});
  console.log('  ✓ cleared quiz_attempts.json');

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceRoleKey) {
    console.log('\n⚠ Supabase credentials missing; local JSON reset done only.');
    console.log('   Create backend/.env with:');
    console.log('   - SUPABASE_URL=...');
    console.log('   - SUPABASE_SERVICE_ROLE_KEY=...');
    console.log('\nThen re-run: node scripts/reset_published_content.js --include-drafts');
    console.log('\n✅ Done (local-only)');
    return;
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 2) Delete published courses
  {
    const { error } = await supabase.from('courses').delete().eq('status', 'published');
    if (error) {
      console.error('  ✗ failed deleting published courses:', error.message);
      process.exit(1);
    }
    console.log('  ✓ deleted courses(status=published)');
  }

  // 3) Delete cases (active by default; optionally include drafts)
  const statusesToDelete = includeDrafts ? ['draft', 'active', 'archived'] : ['active'];

  const { data: cases, error: caseListErr } = await supabase
    .from('cases')
    .select('id,status')
    .in('status', statusesToDelete);

  if (caseListErr) {
    console.error('  ✗ failed listing cases:', caseListErr.message);
    process.exit(1);
  }

  const caseIds = (cases || []).map((c) => c.id);
  if (caseIds.length === 0) {
    console.log('  ✓ no cases to delete');
    console.log('\n✅ Done');
    return;
  }

  // 3b) Delete dependent content to avoid foreign-key failures (keep users)
  // - chat_messages -> session_annotations -> sessions -> exam_assignments -> courses -> case_exams -> cases
  {
    const { data: sessions, error } = await supabase
      .from('sessions')
      .select('id')
      .in('case_id', caseIds);
    if (error) {
      console.error('  ✗ failed listing sessions:', error.message);
      process.exit(1);
    }

    const sessionIds = (sessions || []).map((s) => s.id);
    if (sessionIds.length > 0) {
      const r1 = await supabase.from('chat_messages').delete().in('session_id', sessionIds);
      if (r1.error) {
        console.error('  ✗ failed deleting chat_messages:', r1.error.message);
        process.exit(1);
      }
      console.log(`  ✓ deleted chat_messages for ${sessionIds.length} sessions`);

      const r2 = await supabase.from('session_annotations').delete().in('session_id', sessionIds);
      if (r2.error) {
        console.error('  ✗ failed deleting session_annotations:', r2.error.message);
        process.exit(1);
      }
      console.log(`  ✓ deleted session_annotations for ${sessionIds.length} sessions`);

      const r3 = await supabase.from('sessions').delete().in('id', sessionIds);
      if (r3.error) {
        console.error('  ✗ failed deleting sessions:', r3.error.message);
        process.exit(1);
      }
      console.log(`  ✓ deleted sessions for ${caseIds.length} cases`);
    } else {
      console.log('  ✓ no sessions to delete');
    }
  }

  {
    const { error } = await supabase.from('exam_assignments').delete().in('case_id', caseIds);
    if (error) {
      console.error('  ✗ failed deleting exam_assignments:', error.message);
      process.exit(1);
    }
    console.log('  ✓ deleted exam_assignments for selected cases');
  }

  {
    const { error } = await supabase.from('courses').delete().in('case_id', caseIds);
    if (error) {
      console.error('  ✗ failed deleting courses linked to cases:', error.message);
      process.exit(1);
    }
    console.log('  ✓ deleted courses linked to selected cases');
  }

  // Delete dependent rows first
  {
    const { error } = await supabase.from('case_exams').delete().in('case_id', caseIds);
    if (error) {
      console.error('  ✗ failed deleting case_exams:', error.message);
      process.exit(1);
    }
    console.log(`  ✓ deleted case_exams for ${caseIds.length} cases`);
  }

  {
    const { error } = await supabase.from('cases').delete().in('id', caseIds);
    if (error) {
      console.error('  ✗ failed deleting cases:', error.message);
      process.exit(1);
    }
    console.log(`  ✓ deleted cases (${statusesToDelete.join(', ')})`);
  }

  console.log('\n✅ Done');
}

main().catch((err) => {
  console.error('Unexpected error:', err?.message || String(err));
  process.exit(1);
});
