import { BadRequestException } from '@nestjs/common';
import type { Address } from '@prisma/client';
import { REGISTRATION_TREE } from '../constants/address-tree';

export function assertAddressSelection(
  block: string,
  complex: string,
  building: string,
): void {
  const blockTree = REGISTRATION_TREE[block];
  if (!blockTree) {
    throw new BadRequestException('Invalid block selection.');
  }

  const buildings = blockTree[complex];
  if (!buildings) {
    throw new BadRequestException('Invalid complex selection.');
  }

  if (!buildings.includes(Number(building))) {
    throw new BadRequestException('Invalid building selection.');
  }
}

export function buildAddressLabel(address: Pick<
  Address,
  'block' | 'complex' | 'building' | 'apartment' | 'streetAddress'
>): string {
  return [
    `Block ${address.block}`,
    address.complex,
    `Building ${address.building}`,
    `Apartment ${address.apartment}`,
    address.streetAddress,
  ].join(' - ');
}
