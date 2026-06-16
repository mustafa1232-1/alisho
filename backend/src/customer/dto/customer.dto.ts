import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class AddCartItemDto {
  @IsString()
  @IsNotEmpty()
  productId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity!: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  selectedOptionValueIds?: string[];
}

export class UpdateCartItemDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  selectedOptionValueIds?: string[];
}

export class ApplyPromoDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  code!: string;
}

export class CreateOrderDto {
  @IsOptional()
  @IsString()
  addressId?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class CancelOrderDto {
  @IsOptional()
  @IsString()
  reason?: string;
}

export class CreateServiceOrderDto {
  @IsString()
  @IsNotEmpty()
  serviceId!: string;

  @IsOptional()
  @IsString()
  addressId?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
