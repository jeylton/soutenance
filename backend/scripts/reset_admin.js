require('dotenv').config();

const bcrypt = require('bcryptjs');
const { createClient } = require('@supabase/supabase-js');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      args[key] = next;
      i++;
    } else {
      args[key] = true;
    }
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const email = (args.email || process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  const password = args.password || process.env.ADMIN_PASSWORD;
  const fullName = args.name || process.env.ADMIN_NAME || 'Admin';

  if (!email || !password) {
    console.error('Usage: node scripts/reset_admin.js --email <email> --password <password> [--name "Full Name"]');
    console.error('Or set env: ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_NAME');
    process.exit(1);
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment (.env).');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const passwordHash = await bcrypt.hash(password, 12);

  const { data: existing, error: findErr } = await supabase
    .from('users')
    .select('id,email,role')
    .eq('email', email)
    .maybeSingle();

  if (findErr) {
    console.error('Database error while looking up user:', findErr.message);
    process.exit(1);
  }

  if (existing?.id) {
    const { error: updateErr } = await supabase
      .from('users')
      .update({
        password_hash: passwordHash,
        role: 'admin',
        origin: 'web',
        full_name: fullName,
        profile_type: 'autre',
      })
      .eq('id', existing.id);

    if (updateErr) {
      console.error('Failed to update admin user:', updateErr.message);
      process.exit(1);
    }

    console.log(`✅ Admin updated: ${email}`);
    return;
  }

  const { data: created, error: insertErr } = await supabase
    .from('users')
    .insert([
      {
        email,
        password_hash: passwordHash,
        full_name: fullName,
        profile_type: 'autre',
        origin: 'web',
        role: 'admin',
      },
    ])
    .select('id,email,role')
    .single();

  if (insertErr) {
    console.error('Failed to create admin user:', insertErr.message);
    process.exit(1);
  }

  console.log(`✅ Admin created: ${created.email}`);
}

main().catch((err) => {
  console.error('Unexpected error:', err?.message || String(err));
  process.exit(1);
});
