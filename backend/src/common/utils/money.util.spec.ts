import { applyFee, roundCurrency, toNumber } from './money.util';

describe('money.util', () => {
  it('rounds currency to two decimals', () => {
    expect(roundCurrency(10.126)).toBe(10.13);
    expect(roundCurrency(10.124)).toBe(10.12);
  });

  it('applies fixed fees directly', () => {
    expect(applyFee(100, 2500, 'FIXED')).toBe(2500);
  });

  it('applies percentage fees against the subtotal', () => {
    expect(applyFee(12500, 10, 'PERCENTAGE')).toBe(1250);
    expect(applyFee(999.99, 5, 'PERCENTAGE')).toBe(50);
  });

  it('normalizes nullable values to numbers', () => {
    expect(toNumber(null)).toBe(0);
    expect(toNumber(undefined)).toBe(0);
    expect(toNumber('42.5')).toBe(42.5);
    expect(toNumber(18)).toBe(18);
  });
});
