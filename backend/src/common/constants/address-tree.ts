type RegistrationTree = Record<
  string,
  Record<string, number[]>
>;

function buildRange(start: number, end: number): number[] {
  return Array.from({ length: end - start + 1 }, (_value, index) => start + index);
}

function buildBlock(prefix: 'A' | 'B', buildingCount: number): Record<string, number[]> {
  return Array.from({ length: 9 }, (_value, index) => index + 1).reduce<
    Record<string, number[]>
  >((accumulator, index) => {
    const complex = `${prefix}${index}`;
    const start = index * 100 + 1;
    accumulator[complex] = buildRange(start, start + buildingCount - 1);
    return accumulator;
  }, {});
}

export const REGISTRATION_TREE: RegistrationTree = {
  A: buildBlock('A', 12),
  B: buildBlock('B', 18),
};

export const STUDENT_STAGES = [
  'الابتدائية',
  'المتوسطة',
  'الإعدادية',
  'الجامعة',
  'الدراسات العليا',
];
