const app = require('./src/app');
const port = process.env.PORT || 5000;

app.listen(port, '0.0.0.0', () => {
    console.log(`Server is running on 0.0.0.0:${port}`);
});
