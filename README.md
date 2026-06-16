# Alisho Library Monorepo

Alisho Library is a full-stack monorepo with a single Flutter client in `app/` and a NestJS + Prisma backend in `backend/`.

## Repository Layout

- `app/`: Flutter application for customer, admin, and delivery roles.
- `backend/`: NestJS API, Prisma schema, local file storage, and local PostgreSQL helper script.
- `docs/`: ERD, API notes, and deployment notes.

## Stack

- Flutter desktop/mobile client with Riverpod, go_router, dio, secure storage, printing, and localization.
- NestJS backend with Prisma, PostgreSQL, JWT auth, role guards, file storage, and WebSocket notifications.
- Native PostgreSQL helper for this Windows machine, plus optional Docker Compose for later container use.

## Node Version

Backend runtime is pinned to Node 22 LTS. Use `.nvmrc` or install a Node 22 release explicitly before backend package work.

## Quick Start

1. Install Node 22 LTS, Flutter, and PostgreSQL binaries.
2. Copy `backend/.env.example` to `backend/.env` if you want a fresh local env file.
3. Run `npm run backend:install`.
4. Run `npm run backend:db:start`.
5. Run `npm run backend:prisma:generate`.
6. Run `npm run backend:migrate`.
7. Run `npm run backend:seed`.
8. Run `npm run backend:dev`.
9. In a second terminal run `npm run app:pub:get`.
10. Start the Flutter client from `app/`:
    `flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:4000`

For Android emulator use:
`flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000`

## Default Accounts

- Admin: `07700000000 / Admin@12345`
- Delivery: `07711111111 / Delivery@12345`
- Customer: `07722222222 / Customer@12345`

## Workspace Scripts

- `npm run backend:db:start`
- `npm run backend:db:stop`
- `npm run backend:dev`
- `npm run backend:test`
- `npm run backend:test:e2e`
- `npm run app:analyze`
- `npm run app:test`
- `npm run app:build:windows`
- `npm run verify`

## Docker

`docker-compose.yml` is included for a future PostgreSQL container flow. It exposes PostgreSQL on `127.0.0.1:55433`, so update `DATABASE_URL` if you switch from the native helper to Docker.

## Documentation

- `docs/erd.md`
- `docs/api-notes.md`
- `docs/deployment-notes.md`
