import { Decimal } from '@prisma/client/runtime/library';

export function normalizeForJson<T>(value: T): T {
  if (value instanceof Decimal) {
    return value.toNumber() as T;
  }

  if (Array.isArray(value)) {
    return value.map((entry) => normalizeForJson(entry)) as T;
  }

  if (value instanceof Date) {
    return value.toISOString() as T;
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [key, normalizeForJson(entry)]),
    ) as T;
  }

  return value;
}
