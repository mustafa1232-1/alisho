import { resolve } from 'node:path';

export const appConfig = () => ({
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 4000),
  databaseUrl:
    process.env.DATABASE_URL ??
    'postgresql://postgres@127.0.0.1:55432/alisho_library?schema=public',
  corsOrigins: (process.env.CORS_ORIGIN ??
    'http://localhost:4000,http://localhost:3000,http://localhost:8080')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  jwt: {
    accessSecret:
      process.env.JWT_ACCESS_SECRET ?? 'alisho-dev-access-secret-change-me',
    refreshSecret:
      process.env.JWT_REFRESH_SECRET ?? 'alisho-dev-refresh-secret-change-me',
    accessTtl: process.env.JWT_ACCESS_TTL ?? '15m',
    refreshTtl: process.env.JWT_REFRESH_TTL ?? '30d',
  },
  storageRoot: resolve(process.cwd(), process.env.STORAGE_ROOT ?? 'storage'),
});

export type AppConfig = ReturnType<typeof appConfig>;
