import { Injectable } from '@nestjs/common';
import { REGISTRATION_TREE, STUDENT_STAGES } from '../common/constants/address-tree';

@Injectable()
export class MetaService {
  getRegistrationMeta() {
    return {
      blocks: REGISTRATION_TREE,
      studentStages: STUDENT_STAGES,
      customerTypes: ['STUDENT', 'EMPLOYEE'],
    };
  }
}
