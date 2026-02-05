import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HTTPServer } from 'http';
import jwt from 'jsonwebtoken';
import env from '../config/env';
import logger from '../config/logger';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  username?: string;
}

class RealtimeService {
  private io: SocketIOServer | null = null;
  private userSockets: Map<string, Set<string>> = new Map(); // userId -> Set of socket IDs

  initialize(httpServer: HTTPServer): void {
    this.io = new SocketIOServer(httpServer, {
      cors: {
        origin: env.NODE_ENV === 'production' ? [] : '*',
        credentials: true,
      },
      path: '/socket.io',
    });

    // Authentication middleware
    this.io.use(async (socket: AuthenticatedSocket, next) => {
      try {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');

        if (!token) {
          return next(new Error('Authentication token required'));
        }

        // Verify JWT token
        const decoded = jwt.verify(token, env.JWT_SECRET) as { userId: string; username: string };
        
        socket.userId = decoded.userId;
        socket.username = decoded.username;

        logger.info('WebSocket authenticated', {
          userId: decoded.userId,
          socketId: socket.id,
        });

        next();
      } catch (error) {
        logger.error('WebSocket authentication failed', { error });
        next(new Error('Invalid authentication token'));
      }
    });

    // Connection handler
    this.io.on('connection', (socket: AuthenticatedSocket) => {
      this.handleConnection(socket);
    });

    logger.info('WebSocket server initialized');
  }

  private handleConnection(socket: AuthenticatedSocket): void {
    const userId = socket.userId!;

    // Track user's socket
    if (!this.userSockets.has(userId)) {
      this.userSockets.set(userId, new Set());
    }
    this.userSockets.get(userId)!.add(socket.id);

    logger.info('Client connected', {
      userId,
      socketId: socket.id,
      totalConnections: this.io?.engine.clientsCount || 0,
    });

    // Join user's personal room
    socket.join(`user:${userId}`);

    // Send welcome message
    socket.emit('connected', {
      message: 'Connected to Ordo real-time server',
      userId,
      timestamp: new Date().toISOString(),
    });

    // Handle disconnection
    socket.on('disconnect', (reason) => {
      this.handleDisconnection(socket, reason);
    });

    // Handle ping/pong for connection health
    socket.on('ping', () => {
      socket.emit('pong', { timestamp: new Date().toISOString() });
    });

    // Subscribe to specific channels
    socket.on('subscribe', (data: { channel: string }) => {
      if (data.channel) {
        socket.join(data.channel);
        socket.emit('subscribed', { channel: data.channel });
        logger.info('Client subscribed to channel', {
          userId,
          socketId: socket.id,
          channel: data.channel,
        });
      }
    });

    // Unsubscribe from channels
    socket.on('unsubscribe', (data: { channel: string }) => {
      if (data.channel) {
        socket.leave(data.channel);
        socket.emit('unsubscribed', { channel: data.channel });
        logger.info('Client unsubscribed from channel', {
          userId,
          socketId: socket.id,
          channel: data.channel,
        });
      }
    });
  }

  private handleDisconnection(socket: AuthenticatedSocket, reason: string): void {
    const userId = socket.userId!;

    // Remove socket from tracking
    const userSocketSet = this.userSockets.get(userId);
    if (userSocketSet) {
      userSocketSet.delete(socket.id);
      if (userSocketSet.size === 0) {
        this.userSockets.delete(userId);
      }
    }

    logger.info('Client disconnected', {
      userId,
      socketId: socket.id,
      reason,
      totalConnections: this.io?.engine.clientsCount || 0,
    });
  }

  // Emit transaction status update to user
  emitTransactionUpdate(userId: string, transaction: any): void {
    if (!this.io) return;

    this.io.to(`user:${userId}`).emit('transaction:update', {
      type: 'transaction_update',
      data: transaction,
      timestamp: new Date().toISOString(),
    });

    logger.debug('Transaction update emitted', {
      userId,
      transactionId: transaction.id,
      status: transaction.status,
    });
  }

  // Emit approval queue notification to user
  emitApprovalNotification(userId: string, approval: any): void {
    if (!this.io) return;

    this.io.to(`user:${userId}`).emit('approval:notification', {
      type: 'approval_notification',
      data: approval,
      timestamp: new Date().toISOString(),
    });

    logger.debug('Approval notification emitted', {
      userId,
      approvalId: approval.id,
      requestType: approval.request_type,
    });
  }

  // Emit portfolio update to user
  emitPortfolioUpdate(userId: string, portfolio: any): void {
    if (!this.io) return;

    this.io.to(`user:${userId}`).emit('portfolio:update', {
      type: 'portfolio_update',
      data: portfolio,
      timestamp: new Date().toISOString(),
    });

    logger.debug('Portfolio update emitted', {
      userId,
    });
  }

  // Emit balance change to user
  emitBalanceChange(userId: string, balance: any): void {
    if (!this.io) return;

    this.io.to(`user:${userId}`).emit('balance:change', {
      type: 'balance_change',
      data: balance,
      timestamp: new Date().toISOString(),
    });

    logger.debug('Balance change emitted', {
      userId,
      walletId: balance.walletId,
    });
  }

  // Emit price update to all connected clients
  emitPriceUpdate(tokenMint: string, price: number): void {
    if (!this.io) return;

    this.io.emit('price:update', {
      type: 'price_update',
      data: {
        tokenMint,
        price,
      },
      timestamp: new Date().toISOString(),
    });

    logger.debug('Price update emitted', {
      tokenMint,
      price,
    });
  }

  // Emit NFT portfolio update to user
  emitNFTUpdate(userId: string, nft: any): void {
    if (!this.io) return;

    this.io.to(`user:${userId}`).emit('nft:update', {
      type: 'nft_update',
      data: nft,
      timestamp: new Date().toISOString(),
    });

    logger.debug('NFT update emitted', {
      userId,
      mintAddress: nft.mint_address,
    });
  }

  // Broadcast system notification to all users
  broadcastSystemNotification(notification: any): void {
    if (!this.io) return;

    this.io.emit('system:notification', {
      type: 'system_notification',
      data: notification,
      timestamp: new Date().toISOString(),
    });

    logger.info('System notification broadcasted', {
      message: notification.message,
    });
  }

  // Get connected users count
  getConnectedUsersCount(): number {
    return this.userSockets.size;
  }

  // Get total connections count
  getTotalConnectionsCount(): number {
    return this.io?.engine.clientsCount || 0;
  }

  // Check if user is connected
  isUserConnected(userId: string): boolean {
    return this.userSockets.has(userId);
  }

  // Get user's socket count
  getUserSocketCount(userId: string): number {
    return this.userSockets.get(userId)?.size || 0;
  }

  // Disconnect user (admin action)
  disconnectUser(userId: string, reason: string = 'Admin action'): void {
    if (!this.io) return;

    const socketIds = this.userSockets.get(userId);
    if (socketIds) {
      socketIds.forEach((socketId) => {
        const socket = this.io!.sockets.sockets.get(socketId);
        if (socket) {
          socket.emit('disconnected', { reason });
          socket.disconnect(true);
        }
      });
    }

    logger.info('User disconnected by admin', { userId, reason });
  }

  // Shutdown WebSocket server
  shutdown(): void {
    if (this.io) {
      this.io.close();
      this.io = null;
      this.userSockets.clear();
      logger.info('WebSocket server shut down');
    }
  }
}

export default new RealtimeService();
