import { BadRequestException } from '@nestjs/common';
import { assertAddressSelection, buildAddressLabel } from './address.util';

describe('address.util', () => {
  it('accepts valid block, complex, and building combinations', () => {
    expect(() => assertAddressSelection('A', 'A1', '101')).not.toThrow();
    expect(() => assertAddressSelection('B', 'B9', '918')).not.toThrow();
  });

  it('rejects invalid block selections', () => {
    expect(() => assertAddressSelection('C', 'C1', '101')).toThrow(BadRequestException);
  });

  it('rejects invalid complex selections', () => {
    expect(() => assertAddressSelection('A', 'B1', '101')).toThrow(BadRequestException);
  });

  it('rejects invalid building selections', () => {
    expect(() => assertAddressSelection('A', 'A1', '999')).toThrow(BadRequestException);
  });

  it('builds a readable address label', () => {
    expect(
      buildAddressLabel({
        block: 'A',
        complex: 'A1',
        building: '101',
        apartment: '7',
        streetAddress: 'Near gate 1',
      } as never),
    ).toBe('Block A - A1 - Building 101 - Apartment 7 - Near gate 1');
  });
});
