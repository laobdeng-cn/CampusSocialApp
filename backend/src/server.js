const cors = require('cors');
const dotenv = require('dotenv');
const express = require('express');

const { connectToMongo } = require('./db');
const apiRoutes = require('./routes');

dotenv.config();

const app = express();
const port = Number(process.env.PORT || 4000);
const corsOrigin = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((item) => item.trim())
  : '*';

app.use(cors({ origin: corsOrigin }));
app.use(express.json({ limit: '2mb' }));

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    service: 'campus-social-api',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api', apiRoutes);

app.use((request, response) => {
  response.status(404).json({
    message: `Route not found: ${request.method} ${request.originalUrl}`,
  });
});

connectToMongo().finally(() => {
  app.listen(port, () => {
    console.log(`Campus Social API listening on http://localhost:${port}`);
  });
});
