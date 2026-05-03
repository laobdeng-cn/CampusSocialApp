const cors = require('cors');
const dotenv = require('dotenv');
const express = require('express');
const fs = require('fs');
const path = require('path');

const { connectToMongo } = require('./db');
const apiRoutes = require('./routes');
const feedRoutes = require('./feedRoutes');
const { seedDemoData } = require('./seedDemoData');

dotenv.config();

const app = express();
const port = Number(process.env.PORT || 4000);
const uploadDir = path.join(__dirname, '..', 'uploads');
const corsOrigin = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((item) => item.trim())
  : '*';

fs.mkdirSync(uploadDir, { recursive: true });

app.use(cors({ origin: corsOrigin }));
app.use(express.json({ limit: '2mb' }));
app.use('/uploads', express.static(uploadDir));

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    service: 'campus-social-api',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api', feedRoutes);
app.use('/api', apiRoutes);

app.use((request, response) => {
  response.status(404).json({
    message: `Route not found: ${request.method} ${request.originalUrl}`,
  });
});

app.use((error, _request, response, _next) => {
  console.error(error);
  response.status(500).json({
    message: error.message || '服务器内部错误',
  });
});

connectToMongo()
  .then(seedDemoData)
  .catch((error) => {
    console.warn(`Demo data seed skipped. ${error.message}`);
  })
  .finally(() => {
    app.listen(port, () => {
      console.log(`Campus Social API listening on http://localhost:${port}`);
    });
  });
