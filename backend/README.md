# Campus Social Backend

Express + Mongoose API for the Flutter campus social app.

## Run

```bash
cp .env.example .env
npm install
npm run dev
```

The backend now uses real MongoDB data only. Demo seed data has been removed. If `MONGODB_URI` is not configured or MongoDB is unavailable, API requests should return empty results or database errors instead of mock/demo records.

## Prepare defense demo data

For a clean live demo, run:

```bash
npm run seed:demo-showcase
```

This creates a small controlled dataset with demo accounts, natural campus activities, one full activity, one currently check-in-able activity, notifications, messages, history, and drafts.

Useful accounts:

- `demo_student_001` / `123456`
- `demo_organizer_001` / `123456`

The check-in code is `campus2026`.

## Remove existing demo records

If your local MongoDB already contains old demo data, run:

```bash
npm run cleanup:demo
```

This cleanup script removes known demo users, demo posts, demo activities, and related records. It does not create new data.

## Endpoints

- `GET /health`
- `GET /api/users`
- `GET /api/posts`
- `GET /api/activities`
- `GET /api/groups`
- `GET /api/topics`
- `GET /api/search?q=摄影`
