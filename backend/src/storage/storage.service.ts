import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FileAssetKind, type FileAsset } from '@prisma/client';
import { PDFDocument } from 'pdf-lib';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StorageService {
  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  private get storageRoot(): string {
    return this.configService.get<string>('storageRoot') ?? join(process.cwd(), 'storage');
  }

  async ensureRoot(): Promise<void> {
    await mkdir(this.storageRoot, { recursive: true });
  }

  async saveUploadedFile(
    file: Express.Multer.File,
    kind: FileAssetKind,
    createdById?: string,
  ): Promise<FileAsset> {
    await this.ensureRoot();

    const extension = extname(file.originalname) || this.extensionFromMime(file.mimetype);
    const relativeDir = kind.toLowerCase();
    const absoluteDir = join(this.storageRoot, relativeDir);
    await mkdir(absoluteDir, { recursive: true });

    const fileName = `${Date.now()}-${randomUUID()}${extension}`;
    const diskPath = join(absoluteDir, fileName);
    await writeFile(diskPath, file.buffer);

    return this.prisma.fileAsset.create({
      data: {
        kind,
        diskPath,
        mimeType: file.mimetype,
        originalName: file.originalname,
        size: file.size,
        createdById,
      },
    });
  }

  async createPdfFromImages(
    assets: FileAsset[],
    createdById?: string,
    originalName = 'generated-images.pdf',
  ): Promise<FileAsset> {
    await this.ensureRoot();
    const pdf = await PDFDocument.create();

    for (const asset of assets) {
      const bytes = await readFile(asset.diskPath);
      const image =
        asset.mimeType === 'image/png'
          ? await pdf.embedPng(bytes)
          : await pdf.embedJpg(bytes);

      const page = pdf.addPage([image.width, image.height]);
      page.drawImage(image, {
        x: 0,
        y: 0,
        width: image.width,
        height: image.height,
      });
    }

    const pdfBytes = await pdf.save();
    const absoluteDir = join(this.storageRoot, FileAssetKind.GENERATED_PDF.toLowerCase());
    await mkdir(absoluteDir, { recursive: true });
    const fileName = `${Date.now()}-${randomUUID()}.pdf`;
    const diskPath = join(absoluteDir, fileName);
    await writeFile(diskPath, pdfBytes);

    return this.prisma.fileAsset.create({
      data: {
        kind: FileAssetKind.GENERATED_PDF,
        diskPath,
        mimeType: 'application/pdf',
        originalName,
        size: pdfBytes.length,
        createdById,
      },
    });
  }

  private extensionFromMime(mimeType: string): string {
    if (mimeType === 'image/png') {
      return '.png';
    }
    if (mimeType === 'image/jpeg') {
      return '.jpg';
    }
    if (mimeType === 'application/pdf') {
      return '.pdf';
    }
    return '';
  }
}
