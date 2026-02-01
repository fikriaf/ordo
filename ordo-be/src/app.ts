import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import env from './config/env';
import logger from './config/logger';
import authRoutes from './routes/auth.routes';
import walletRoutes from './routes/wallet.routes';
import actionRoutes from './routes/action.routes';
import transactionRoutes from './routes/transaction.routes';
import chatRoutes from './routes/chat.routes';
import adminRoutes from './routes/admin.routes';
import healthRoutes from './routes/health.routes';
import { sanitizeInput } from './middleware/sanitization.middleware';
import { rateLimiter, authRateLimiter, adminRateLimiter } from './middleware/rate-limit.middleware';
import { errorHandler, notFoundHandler } from './middleware/error-handler.middleware';

// Initialize Solana Agent Service (registers plugins)
import './services/solana-agent.service';

const app: Application = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: env.NODE_ENV === 'production' ? [] : '*',
  credentials: true,
}));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Input sanitization middleware (must be after body parsing)
app.use(sanitizeInput);

// Global rate limiting (100 requests per minute)
app.use(rateLimiter);

// Request logging middleware
app.use((req, _res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });
  next();
});

// Health check endpoint
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Detailed health checks
app.use('/health', healthRoutes);

// API routes
app.use(`/api/${env.API_VERSION}/auth`, authRateLimiter, authRoutes);
app.use(`/api/${env.API_VERSION}/wallet`, walletRoutes);
app.use(`/api/${env.API_VERSION}/wallets`, walletRoutes);
app.use(`/api/${env.API_VERSION}/actions`, actionRoutes);
app.use(`/api/${env.API_VERSION}/transactions`, transactionRoutes);
app.use(`/api/${env.API_VERSION}/chat`, chatRoutes);
app.use(`/api/${env.API_VERSION}/conversations`, chatRoutes);
app.use(`/api/${env.API_VERSION}/admin`, adminRateLimiter, adminRoutes);

// 404 handler
app.use(notFoundHandler);

// Centralized error handler
app.use(errorHandler);

export default app;
