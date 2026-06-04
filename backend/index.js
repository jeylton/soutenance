const path = require('path');

// Always load backend/.env (works even if server is started from repo root)
require('dotenv').config({ path: path.join(__dirname, '.env') });

const app = require('./src/app');
const port = process.env.PORT || 5000;

// Some clients resolve "localhost" to IPv6 (::1). Listening on "::" accepts IPv6 (and usually IPv4-mapped) connections.
const host = process.env.HOST || '::';

app.listen(port, host, () => {
    console.log(`Server is running on ${host}:${port}`);
});
