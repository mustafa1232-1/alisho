import { CustomerType } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  fullName!: string;

  @IsInt()
  @Min(10)
  @Max(100)
  age!: number;

  @IsString()
  @Matches(/^07\d{9}$/)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  streetAddress!: string;

  @IsString()
  @IsNotEmpty()
  block!: string;

  @IsString()
  @IsNotEmpty()
  complex!: string;

  @IsString()
  @IsNotEmpty()
  building!: string;

  @IsString()
  @IsNotEmpty()
  apartment!: string;

  @IsEnum(CustomerType)
  customerType!: CustomerType;

  @IsOptional()
  @IsString()
  jobTitle?: string;

  @IsOptional()
  @IsString()
  studentStage?: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsString()
  @MinLength(8)
  confirmPassword!: string;
}

export class LoginDto {
  @IsString()
  @Matches(/^07\d{9}$/)
  phone!: string;

  @IsString()
  @MinLength(8)
  password!: string;
}

export class RefreshTokenDto {
  @IsString()
  @IsNotEmpty()
  refreshToken!: string;
}
