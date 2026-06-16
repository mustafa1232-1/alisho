import { Prisma } from '@prisma/client';

export function roundCurrency(value: number): number {
  return Math.round(value * 100) / 100;
}

export function toDecimal(value: number): Prisma.Decimal {
  return new Prisma.Decimal(roundCurrency(value));
}

export function toNumber(
  value: Prisma.Decimal | number | string | null | undefined,
): number {
  if (value === null || value === undefined) {
    return 0;
  }

  if (typeof value === 'number') {
    return value;
  }

  if (typeof value === 'string') {
    return Number(value);
  }

  return value.toNumber();
}

export function applyFee(subtotal: number, amount: number, mode: 'FIXED' | 'PERCENTAGE'): number {
  if (mode === 'PERCENTAGE') {
    return roundCurrency((subtotal * amount) / 100);
  }

  return roundCurrency(amount);
}
