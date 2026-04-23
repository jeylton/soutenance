/**
 * Simple validation middleware factory
 * Usage: validate({ body: { email: 'required', password: 'required' } })
 */
const validate = (schema) => (req, res, next) => {
  const errors = [];

  if (schema.body) {
    for (const [field, rule] of Object.entries(schema.body)) {
      const value = req.body[field];
      if (rule === 'required' && (value === undefined || value === null || value === '')) {
        errors.push(`Le champ '${field}' est requis`);
      }
      if (rule === 'email' && value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(value)) {
          errors.push(`Le champ '${field}' doit être un email valide`);
        }
      }
      if (rule === 'number' && value !== undefined && value !== null) {
        if (typeof value !== 'number' && isNaN(Number(value))) {
          errors.push(`Le champ '${field}' doit être un nombre`);
        }
      }
    }
  }

  if (schema.params) {
    for (const [field, rule] of Object.entries(schema.params)) {
      const value = req.params[field];
      if (rule === 'required' && (!value || value === '')) {
        errors.push(`Le paramètre '${field}' est requis`);
      }
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({ errors });
  }

  next();
};

module.exports = { validate };
