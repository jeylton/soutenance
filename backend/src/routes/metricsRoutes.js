const express = require('express');
const router = express.Router();
const supabase = require('../config/supabase');

const safeCount = async (table, filters = {}) => {
  try {
    let query = supabase.from(table).select('*', { count: 'exact', head: true });
    Object.entries(filters).forEach(([col, val]) => {
      query = query.eq(col, val);
    });
    const { count, error } = await query;
    if (error) {
      console.warn(`Supabase count error on ${table}:`, error.message);
      return 0;
    }
    return count || 0;
  } catch (e) {
    console.warn(`Count failed on ${table}:`, e.message);
    return 0;
  }
};

router.get('/', async (_req, res) => {
  const [mobileUsers, clinics, publishedCourses, specialties, activeRecentCases, totalSessions] = await Promise.all([
    safeCount('users', { origin: 'mobile' }),
    safeCount('clinics'),
    safeCount('courses', { status: 'published' }),
    safeCount('specialties'),
    safeCount('cases', { status: 'active' }),
    safeCount('sessions'),
  ]);

  // Fetch recent active cases for the dashboard
  let recentCases = [];
  try {
    const { data } = await supabase
      .from('cases')
      .select('id,patient_name,consultation_reason,difficulty,status,updated_at')
      .eq('status', 'active')
      .order('updated_at', { ascending: false })
      .limit(5);
    recentCases = data || [];
  } catch (_e) { /* ignore */ }

  // Fetch specialty distribution
  let specialtyList = [];
  try {
    const { data } = await supabase.from('specialties').select('id,name');
    specialtyList = data || [];
  } catch (_e) { /* ignore */ }

  res.json({
    mobile_users: mobileUsers,
    clinics,
    published_courses: publishedCourses,
    specialties,
    active_recent_cases: activeRecentCases,
    total_sessions: totalSessions,
    recent_cases: recentCases,
    specialty_list: specialtyList,
  });
});

module.exports = router;
