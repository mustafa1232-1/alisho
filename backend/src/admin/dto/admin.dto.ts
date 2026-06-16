import {
  ArrayNotEmpty,
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateProductDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsString()
  price!: string;

  @IsString()
  stock!: string;

  @IsOptional()
  @IsString()
  isAvailable?: string;

  @IsOptional()
  @IsString()
  isActive?: string;

  @IsOptional()
  @IsString()
  optionGroupsJson?: string;
}

export class UpdateProductDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  price?: string;

  @IsOptional()
  @IsString()
  stock?: string;

  @IsOptional()
  @IsString()
  isAvailable?: string;

  @IsOptional()
  @IsString()
  isActive?: string;

  @IsOptional()
  @IsString()
  optionGroupsJson?: string;
}

export class UpdateAvailabilityDto {
  @IsString()
  isAvailable!: string;
}

export class AddProductOptionsDto {
  @IsString()
  optionGroupsJson!: string;
}

export class MarkUnavailableDto {
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  orderItemIds!: string[];

  @IsOptional()
  @IsString()
  note?: string;
}

export class AssignDeliveryDto {
  @IsString()
  @IsNotEmpty()
  deliveryUserId!: string;

  @IsOptional()
  @IsString()
  etaText?: string;
}

export class CreateBannerDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  link?: string;

  @IsOptional()
  @IsString()
  sortOrder?: string;

  @IsOptional()
  @IsString()
  isActive?: string;
}

export class CreatePromoCodeDto {
  @IsString()
  @IsNotEmpty()
  code!: string;

  @IsString()
  discountType!: string;

  @IsString()
  value!: string;

  @IsString()
  startsAt!: string;

  @IsString()
  endsAt!: string;

  @IsOptional()
  @IsString()
  maxUses?: string;

  @IsOptional()
  @IsString()
  maxUsesPerUser?: string;

  @IsOptional()
  @IsString()
  isActive?: string;
}

export class UpdatePromoCodeDto extends CreatePromoCodeDto {}

export class CreateServiceDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  defaultPrice?: string;

  @IsString()
  pricingMode!: string;

  @IsOptional()
  @IsString()
  requiresFiles?: string;

  @IsOptional()
  @IsString()
  requiresImages?: string;

  @IsOptional()
  @IsString()
  isActive?: string;
}

export class UpdateServiceDto extends CreateServiceDto {}

export class PriceServiceOrderDto {
  @IsString()
  quotedPrice!: string;
}

export class CreateDeliveryUserDto {
  @IsString()
  @IsNotEmpty()
  fullName!: string;

  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsString()
  @MaxLength(100)
  password!: string;

  @IsOptional()
  @IsString()
  vehicleInfo?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpdateDeliveryUserDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  password?: string;

  @IsOptional()
  @IsString()
  vehicleInfo?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  isActive?: string;
}

export class UpdateSettingsDto {
  @IsOptional()
  @IsString()
  deliveryMode?: string;

  @IsOptional()
  @IsString()
  deliveryAmount?: string;

  @IsOptional()
  @IsString()
  deliveryEnabled?: string;

  @IsOptional()
  @IsString()
  serviceMode?: string;

  @IsOptional()
  @IsString()
  serviceAmount?: string;

  @IsOptional()
  @IsString()
  serviceEnabled?: string;

  @IsOptional()
  @IsString()
  extraFeeAmount?: string;

  @IsOptional()
  @IsString()
  extraFeeEnabled?: string;

  @IsOptional()
  @IsString()
  appPreferencesJson?: string;
}
