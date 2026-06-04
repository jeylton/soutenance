const fs = require('fs');
const path = require('path');

// Always load backend/.env, even if started from another working directory.
// Falls back to default dotenv search when backend/.env is missing.
const backendEnvPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(backendEnvPath)) {
  require('dotenv').config({ path: backendEnvPath });
} else {
  require('dotenv').config();
}

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const supabase = require('./config/supabase');

const app = express();

// Lightweight migration: ensure specialty_id column exists on cases
(async () => {
  try {
    // Try to read the column — if it fails, the column doesn't exist
    const { error } = await supabase.from('cases').select('specialty_id').limit(1);
    if (error && error.message.includes('specialty_id')) {
      console.log('[Migration] specialty_id column missing on cases — attempting to add it...');
      // Use rpc to run raw SQL if available, otherwise log instructions
      try {
        const { error: rpcErr } = await supabase.rpc('exec_sql', {
          query: 'ALTER TABLE cases ADD COLUMN IF NOT EXISTS specialty_id bigint REFERENCES specialties(id) ON DELETE SET NULL;'
        });
        if (rpcErr) {
          console.log('[Migration] Could not auto-add specialty_id. Please run in Supabase SQL Editor:');
          console.log('  ALTER TABLE cases ADD COLUMN IF NOT EXISTS specialty_id bigint REFERENCES specialties(id) ON DELETE SET NULL;');
        } else {
          console.log('[Migration] specialty_id column added successfully!');
        }
      } catch (_) {
        console.log('[Migration] Please run in Supabase SQL Editor:');
        console.log('  ALTER TABLE cases ADD COLUMN IF NOT EXISTS specialty_id bigint REFERENCES specialties(id) ON DELETE SET NULL;');
      }
    } else {
      console.log('[Migration] specialty_id column OK');
    }
  } catch (e) {
    console.warn('[Migration] check skipped:', e.message);
  }
})();

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());

// Static media used by both web and mobile clients
app.use('/avatars', express.static(path.join(__dirname, '..', 'public', 'avatars')));

// Basic Route
app.get('/', (req, res) => {
  res.json({ message: 'Welcome to Dica Clinic API' });
});

// API Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/metrics', require('./routes/metricsRoutes'));
app.use('/api/users', require('./routes/userRoutes'));
app.use('/api/cases', require('./routes/caseRoutes'));
app.use('/api/sessions', require('./routes/sessionsRoutes'));
app.use('/api/llm', require('./routes/llmRoutes'));
app.use('/api/courses', require('./routes/coursesRoutes'));
app.use('/api/specialties', require('./routes/specialtyRoutes'));
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/chat', require('./routes/chatRoutes'));
app.use('/api/gamification', require('./routes/gamificationRoutes'));
app.use('/api/notifications', require('./routes/notificationRoutes'));
app.use('/api/exam-assignments', require('./routes/examAssignmentRoutes'));
app.use('/api/annotations', require('./routes/annotationRoutes'));
app.use('/api/settings', require('./routes/settingsRoutes'));

module.exports = app;
