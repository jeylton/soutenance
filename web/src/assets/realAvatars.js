const resolveApiBase = () => {
  const envBase = (import.meta.env.VITE_API_URL || '').trim().replace(/\/$/, '');
  if (envBase) return envBase;
  if (typeof window === 'undefined') return 'http://localhost:5000';
  const host = window.location.hostname;
  if (host === 'localhost' || host === '127.0.0.1') return 'http://localhost:5000';
  return '';
};

const API_BASE = resolveApiBase();

const voiceOr = (envName, fallback) => (import.meta.env[envName] || fallback || '').trim();

const toAbsoluteUrl = (path) => {
  if (!path) return '';
  // Encode spaces in path segments
  const encoded = path.split('/').map(s => s ? encodeURIComponent(s) : s).join('/');
  return API_BASE ? `${API_BASE}${encoded}` : encoded;
};

const normalizeGender = (gender) => {
  const g = (gender || '').toString().toLowerCase();
  if (g.startsWith('f')) return 'female';
  if (g.startsWith('m')) return 'male';
  return 'male';
};

const ageToGroup = (age) => {
  const n = Number(age);
  if (!Number.isFinite(n)) return 'adult';
  if (n <= 14) return 'child';
  if (n >= 60) return 'senior';
  return 'adult';
};

// ─── Catégories avec tous les gifs disponibles ───────────────────────────────
const CATEGORIES = [
  {
    key: 'male_adult',
    gender: 'male',
    ageGroup: 'adult',
    label: 'Homme adulte',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF1', '101A8UFM73tcrunWGirw'),
    paths: [
      '/avatars/adulte homme.gif',
      '/avatars/adulte homme 2.gif',
      '/avatars/adulte homme 3.gif',
    ],
  },
  {
    key: 'female_adult',
    gender: 'female',
    ageGroup: 'adult',
    label: 'Femme adulte',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF2', 'fBpCO0Kf0krKLYGOu65w'),
    paths: [
      '/avatars/adulte femme.gif',
      '/avatars/adulte femme 2.gif',
      '/avatars/ADULTE FEMME 3.gif',
    ],
  },
  {
    key: 'male_senior',
    gender: 'male',
    ageGroup: 'senior',
    label: 'Homme senior',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF3', '6aRkp7Pz4MBOSpUyJCTO'),
    paths: [
      '/avatars/senior homme.gif',
      '/avatars/senior homme 2.gif',
    ],
  },
  {
    key: 'female_senior',
    gender: 'female',
    ageGroup: 'senior',
    label: 'Femme senior',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF4', 'YxrwjAKoUKULGd0g8K9Y'),
    paths: ['/avatars/senior femme.gif'],
  },
  {
    key: 'male_child',
    gender: 'male',
    ageGroup: 'child',
    label: 'Garçon enfant',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF5', 'FRY6vOtGqwamgAf39SwP'),
    paths: ['/avatars/enfant homme.gif'],
  },
  {
    key: 'female_child',
    gender: 'female',
    ageGroup: 'child',
    label: 'Fille enfant',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF6', 'DOqLhiOMs8JmafdomNTP'),
    paths: ['/avatars/enfant femme.gif'],
  },
];

// Liste plate de tous les avatars disponibles (pour le sélecteur web)
export const REAL_AVATARS = CATEGORIES.flatMap((cat) =>
  cat.paths.map((path) => ({
    hint: cat.key,
    label: path.split('/').pop().replace('.gif', ''),
    path,
    img: toAbsoluteUrl(path),
    gender: cat.gender,
    ageGroup: cat.ageGroup,
    voiceId: cat.voiceId,
    animated: true,
  }))
);

// Retourne un avatar aléatoire pour une catégorie gender+ageGroup donnée
const pickRandom = (gender, ageGroup) => {
  const pool = REAL_AVATARS.filter(
    (a) => a.gender === gender && a.ageGroup === ageGroup
  );
  if (pool.length === 0) return REAL_AVATARS[0];
  return pool[Math.floor(Math.random() * pool.length)];
};

export const resolveAvatarProfile = ({ hint, age, gender } = {}) => {
  // Cherche par path exact (edition d'un cas existant)
  if (hint) {
    const byPath = REAL_AVATARS.find(
      (a) => a.path === hint ||
             a.img === hint ||
             a.path.toLowerCase() === (hint || '').toLowerCase()
    );
    if (byPath) return byPath;
  }

  // Sélection aléatoire dans la bonne catégorie
  const ageGroup = ageToGroup(age);
  const genderNorm = normalizeGender(gender);
  return pickRandom(genderNorm, ageGroup);
};

export const resolveAvatarByValue = (value) => {
  const raw = (value || '').toString().trim();
  if (!raw) return null;
  return (
    REAL_AVATARS.find((a) => a.path === raw) ||
    REAL_AVATARS.find((a) => a.img === raw) ||
    REAL_AVATARS.find((a) => a.path.toLowerCase() === raw.toLowerCase()) ||
    null
  );
};
