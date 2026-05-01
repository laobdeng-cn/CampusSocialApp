# Campus Social Backend

Express + Mongoose API for the Flutter campus social app.

## Run

```bash
cp .env.example .env
npm install
npm run dev
```

If `MONGODB_URI` is not configured or MongoDB is unavailable, the API still starts and serves mock data from `src/data/seed.js`.

## Endpoints

- `GET /health`
- `GET /api/users`
- `GET /api/posts`
- `GET /api/activities`
- `GET /api/groups`
- `GET /api/topics`
- `GET /api/search?q=摄影`
