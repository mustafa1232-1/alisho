# Deployment And Local Dev Notes

## Backend Runtime

- Node 22 LTS
- PostgreSQL
- Local disk storage for uploads, banners, product images, generated PDFs

## Native PostgreSQL On This Machine

The repository includes `backend/scripts/local-postgres.ps1`, which manages a local PostgreSQL data directory under `backend/.local-postgres/`.

Default assumptions:

- PostgreSQL binaries live at `C:\Program Files\PostgreSQL\18\bin`
- Host: `127.0.0.1`
- Port: `55432`
- Database: `alisho_library`
- User: `postgres`

Override the PostgreSQL binary location by setting `PG_BIN` before running:

```powershell
$env:PG_BIN='C:\Program Files\PostgreSQL\18\bin'
npm run backend:db:start
```

## Optional Docker Compose

`docker-compose.yml` provisions PostgreSQL 16 on host port `55433`.

If you use Docker instead of the native helper:

1. Start Docker Desktop.
2. Run `docker compose up -d`.
3. Change `DATABASE_URL` to `postgresql://postgres@127.0.0.1:55433/alisho_library?schema=public`.
4. Run Prisma migration and seed commands again.

## Storage

- Product images, banners, uploads, and generated PDFs are stored on disk under `backend/storage/`.
- `GET /files/:id` is the only supported access path and remains auth guarded.

## Verification Status In This Workspace

The current implementation has been validated locally with:

- `cd backend && npm run build`
- `cd backend && npm test`
- `cd backend && npm run test:e2e`
- `cd app && flutter analyze`
- `cd app && flutter test`
- `cd app && flutter build windows`

iOS remains code-compatible but unverified from this Windows environment.
