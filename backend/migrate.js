const { Client } = require('pg');
const dns = require('dns');
// Force IPv4 resolution
dns.setDefaultResultOrder('ipv4first');

const client = new Client({
  host: 'aws-0-eu-central-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.ezlyyxfpnxbaagzqysze',
  password: '3rvVEhOsZDSKRkZD',
  ssl: { rejectUnauthorized: false }
});

(async () => {
  await client.connect();
  console.log('Connected to PostgreSQL!');

  // 1. Add specialty_id to cases
  try {
    await client.query('ALTER TABLE cases ADD COLUMN IF NOT EXISTS specialty_id bigint REFERENCES specialties(id) ON DELETE SET NULL');
    console.log('OK: specialty_id column added to cases');
  } catch (e) { console.log('specialty_id:', e.message); }

  // 2. Create notifications table if missing
  try {
    await client.query(`CREATE TABLE IF NOT EXISTS notifications (
      id bigint generated always as identity primary key,
      user_id uuid references users(id) on delete cascade,
      title text not null,
      body text,
      type text check (type in ('feedback','badge','xp','exam','system')) default 'system',
      read boolean default false,
      created_at timestamp with time zone default now()
    )`);
    console.log('OK: notifications table created/verified');
  } catch (e) { console.log('notifications:', e.message); }

  // 3. Enable realtime on notifications
  try {
    await client.query('ALTER PUBLICATION supabase_realtime ADD TABLE notifications');
    console.log('OK: realtime enabled for notifications');
  } catch (e) { console.log('realtime:', e.message); }

  // 4. Add missing columns to users
  try {
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash text");
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS role text DEFAULT 'student'");
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS group_name text");
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS phone text");
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS institution text");
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS specialty text");
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS locale text");
    console.log('OK: users columns verified');
  } catch (e) { console.log('users:', e.message); }

  // 5. Add missing columns to sessions
  try {
    await client.query("ALTER TABLE sessions ADD COLUMN IF NOT EXISTS time_spent int");
    await client.query("ALTER TABLE sessions ADD COLUMN IF NOT EXISTS is_exam boolean DEFAULT false");
    await client.query("ALTER TABLE sessions ADD COLUMN IF NOT EXISTS exam_assignment_id bigint");
    await client.query("ALTER TABLE sessions ADD COLUMN IF NOT EXISTS diagnosis text");
    console.log('OK: sessions columns verified');
  } catch (e) { console.log('sessions:', e.message); }

  // 6. Create user_xp table if missing
  try {
    await client.query(`CREATE TABLE IF NOT EXISTS user_xp (
      id bigint generated always as identity primary key,
      user_id uuid references users(id) on delete cascade unique,
      xp int default 0,
      level int default 1
    )`);
    console.log('OK: user_xp table verified');
  } catch (e) { console.log('user_xp:', e.message); }

  // 7. Create exam_assignments table if missing
  try {
    await client.query(`CREATE TABLE IF NOT EXISTS exam_assignments (
      id bigint generated always as identity primary key,
      case_id bigint references cases(id) on delete cascade,
      title text,
      group_name text,
      time_limit int,
      start_date timestamp with time zone,
      end_date timestamp with time zone,
      created_by uuid references users(id),
      created_at timestamp with time zone default now()
    )`);
    console.log('OK: exam_assignments table verified');
  } catch (e) { console.log('exam_assignments:', e.message); }

  // 8. Verify specialty_id
  const res = await client.query("SELECT column_name FROM information_schema.columns WHERE table_name='cases' AND column_name='specialty_id'");
  console.log('Verification - specialty_id exists:', res.rows.length > 0);

  await client.end();
  console.log('Migration complete!');
})();
