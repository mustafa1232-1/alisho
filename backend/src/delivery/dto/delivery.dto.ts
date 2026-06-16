import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class FailDeliveryDto {
  @IsString()
  @IsNotEmpty()
  reason!: string;

  @IsOptional()
  @IsString()
  customReason?: string;
}
