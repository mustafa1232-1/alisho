import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Notification } from '@prisma/client';
import type { Server, Socket } from 'socket.io';

@WebSocketGateway({
  namespace: 'realtime',
  cors: {
    origin: '*',
    credentials: true,
  },
})
export class NotificationsGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(NotificationsGateway.name);

  constructor(private readonly jwtService: JwtService) {}

  async handleConnection(client: Socket): Promise<void> {
    try {
      const token = this.extractToken(client);
      if (!token) {
        client.disconnect(true);
        return;
      }

      const payload = await this.jwtService.verifyAsync<{
        sub: string;
        phone: string;
        role: string;
      }>(token);

      client.data.userId = payload.sub;
      await client.join(this.roomForUser(payload.sub));
    } catch (error) {
      this.logger.warn(`Rejected realtime connection: ${(error as Error).message}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket): void {
    client.leave(this.roomForUser(client.data.userId as string));
  }

  emitNotification(userId: string, notification: Notification): void {
    this.server.to(this.roomForUser(userId)).emit('notification.created', notification);
  }

  emitOrderUpdate(userId: string, payload: Record<string, unknown>): void {
    this.server.to(this.roomForUser(userId)).emit('order.updated', payload);
  }

  private roomForUser(userId: string): string {
    return `user:${userId}`;
  }

  private extractToken(client: Socket): string | null {
    const authHeader = client.handshake.headers.authorization;
    if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
      return authHeader.slice(7);
    }

    const authToken = client.handshake.auth.token;
    if (typeof authToken === 'string') {
      return authToken;
    }

    return null;
  }
}
