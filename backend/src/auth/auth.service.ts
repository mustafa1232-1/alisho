import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { CustomerType, RoleCode } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { assertAddressSelection, buildAddressLabel } from '../common/utils/address.util';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto, RegisterDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    if (dto.password !== dto.confirmPassword) {
      throw new BadRequestException('Password confirmation does not match.');
    }

    if (dto.customerType === 'STUDENT' && !dto.studentStage) {
      throw new BadRequestException('Student stage is required for student accounts.');
    }

    assertAddressSelection(dto.block, dto.complex, dto.building);

    const existing = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    if (existing) {
      throw new BadRequestException('Phone number already exists.');
    }

    const role = await this.prisma.role.findUnique({
      where: { code: RoleCode.CUSTOMER },
    });

    if (!role) {
      throw new BadRequestException('Customer role is not available.');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        fullName: dto.fullName,
        age: dto.age,
        phone: dto.phone,
        passwordHash,
        roleId: role.id,
        customerType: dto.customerType,
        jobTitle:
          dto.customerType === CustomerType.EMPLOYEE ? dto.jobTitle : null,
        studentStage: dto.studentStage,
        addresses: {
          create: {
            block: dto.block,
            complex: dto.complex,
            building: dto.building,
            apartment: dto.apartment,
            streetAddress: dto.streetAddress,
            isPrimary: true,
          },
        },
      },
      include: {
        role: true,
        addresses: true,
      },
    });

    const tokens = await this.issueTokens(user.id, user.phone, user.role.code);
    await this.persistRefreshToken(user.id, tokens.refreshToken);

    return {
      user: this.serializeUser(user),
      tokens,
    };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
      include: {
        role: true,
        addresses: {
          where: { deletedAt: null, isPrimary: true },
          take: 1,
        },
      },
    });

    if (!user || user.deletedAt || !user.isActive) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    const validPassword = await bcrypt.compare(dto.password, user.passwordHash);
    if (!validPassword) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    const tokens = await this.issueTokens(user.id, user.phone, user.role.code);
    await this.persistRefreshToken(user.id, tokens.refreshToken);

    return {
      user: this.serializeUser(user),
      tokens,
    };
  }

  async refresh(refreshToken: string) {
    const payload = await this.verifyRefreshToken(refreshToken);
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: { role: true, addresses: { where: { isPrimary: true }, take: 1 } },
    });

    if (!user || !user.refreshTokenHash) {
      throw new UnauthorizedException('Refresh token is not recognized.');
    }

    const matches = await bcrypt.compare(refreshToken, user.refreshTokenHash);
    if (!matches) {
      throw new UnauthorizedException('Refresh token is invalid.');
    }

    const tokens = await this.issueTokens(user.id, user.phone, user.role.code);
    await this.persistRefreshToken(user.id, tokens.refreshToken);

    return {
      user: this.serializeUser(user),
      tokens,
    };
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        role: true,
        addresses: {
          where: { deletedAt: null },
          orderBy: [{ isPrimary: 'desc' }, { createdAt: 'asc' }],
          take: 1,
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('User not found.');
    }

    return this.serializeUser(user);
  }

  async logout(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshTokenHash: null },
    });

    return { success: true };
  }

  private async issueTokens(userId: string, phone: string, role: RoleCode) {
    const accessToken = await this.jwtService.signAsync(
      { sub: userId, phone, role },
      {
        secret: this.configService.get<string>('jwt.accessSecret'),
        expiresIn: (this.configService.get<string>('jwt.accessTtl') ??
          '15m') as never,
      },
    );

    const refreshToken = await this.jwtService.signAsync(
      { sub: userId, phone, role },
      {
        secret: this.configService.get<string>('jwt.refreshSecret'),
        expiresIn: (this.configService.get<string>('jwt.refreshTtl') ??
          '30d') as never,
      },
    );

    return { accessToken, refreshToken };
  }

  private async persistRefreshToken(userId: string, refreshToken: string) {
    const refreshTokenHash = await bcrypt.hash(refreshToken, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshTokenHash },
    });
  }

  private async verifyRefreshToken(token: string) {
    try {
      return await this.jwtService.verifyAsync<{
        sub: string;
        phone: string;
        role: RoleCode;
      }>(token, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token is invalid.');
    }
  }

  private serializeUser(user: {
    id: string;
    fullName: string;
    phone: string;
    age: number | null;
    customerType: string | null;
    jobTitle: string | null;
    studentStage: string | null;
    role: { code: string; name: string };
    addresses: Array<{
      block: string;
      complex: string;
      building: string;
      apartment: string;
      streetAddress: string;
    }>;
  }) {
    const address = user.addresses[0];
    return {
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      age: user.age,
      role: user.role.code,
      roleLabel: user.role.name,
      customerType: user.customerType,
      jobTitle: user.jobTitle,
      studentStage: user.studentStage,
      address: address
        ? {
            ...address,
            label: buildAddressLabel(address),
          }
        : null,
    };
  }
}
