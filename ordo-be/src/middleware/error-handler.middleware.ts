import { Request, Response, NextFunction } from 'express';
import logger from '../config/logger';
import env from '../config/env';

/**
 * Custom error class with status code
 */
export class AppError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public isOperational: boolean = true,
  ) {
    super(message);
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

/**
 * Error types and their corresponding HTTP status codes
 */
const ERROR_STATUS_MAP: Record<string, number> = {
  ValidationError: 400,
  CastError: 400,
  JsonWebTokenError: 401,
  TokenExpiredError: 401,
  UnauthorizedError: 401,
  ForbiddenError: 403,
  NotFoundError: 404,
  ConflictError: 409,
  RateLimitError: 429,
  InternalServerError: 500,
  DatabaseError: 500,
  ExternalServiceError: 503,
};

/**
 * Sensitive fields that should be redacted from error logs
 */
const SENSITIVE_FIELDS = [
  'password',
  'privateKey',
  'secret',
  'token',
  'apiKey',
  'authorization',
  'cookie',
];

/**
 * Redact sensitive data from objects
 */
function redactSensitiveData(obj: any): any {
  if (!obj || typeof obj !== 'object') {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map(item => redactSensitiveData(item));
  }

  const redacted: any = {};
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      const lowerKey = key.toLowerCase();
      if (SENSITIVE_FIELDS.some(field => lowerKey.includes(field))) {
        redacted[key] = '[REDACTED]';
      } else if (typeof obj[key] === 'object') {
        redacted[key] = redactSensitiveData(obj[key]);
      } else {
        redacted[key] = obj[key];
      }
    }
  }
  return redacted;
}

/**
 * Map error to HTTP status code
 */
function getStatusCode(error: any): number {
  // If error has statusCode property, use it
  if (error.statusCode) {
    return error.statusCode;
  }

  // If error has status property, use it
  if (error.status) {
    return error.status;
  }

  // Map by error name
  if (error.name && ERROR_STATUS_MAP[error.name]) {
    return ERROR_STATUS_MAP[error.name];
  }

  // Default to 500
  return 500;
}

/**
 * Format error response
 */
function formatErrorResponse(error: any, _statusCode: number) {
  const response: any = {
    success: false,
    error: error.message || 'An error occurred',
  };

  // Add error code if available
  if (error.code) {
    response.code = error.code;
  }

  // Add validation errors if available
  if (error.errors) {
    response.errors = error.errors;
  }

  // Add stack trace in development mode
  if (env.NODE_ENV === 'development') {
    response.stack = error.stack;
  }

  return response;
}

/**
 * Centralized error handling middleware
 * 
 * This middleware:
 * 1. Maps errors to appropriate HTTP status codes
 * 2. Formats error responses consistently
 * 3. Logs errors with context (redacting sensitive data)
 * 4. Handles operational vs programming errors differently
 */
export function errorHandler(
  error: any,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  const statusCode = getStatusCode(error);

  // Log error with context (redact sensitive data)
  const logContext = {
    error: {
      name: error.name,
      message: error.message,
      code: error.code,
      statusCode,
    },
    request: {
      method: req.method,
      path: req.path,
      query: redactSensitiveData(req.query),
      body: redactSensitiveData(req.body),
      params: req.params,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    },
  };

  // Log based on severity
  if (statusCode >= 500) {
    logger.error('Server error', {
      ...logContext,
      stack: error.stack,
    });
  } else if (statusCode >= 400) {
    logger.warn('Client error', logContext);
  } else {
    logger.info('Request error', logContext);
  }

  // Send error response
  const response = formatErrorResponse(error, statusCode);
  res.status(statusCode).json(response);
}

/**
 * Handle 404 errors
 */
export function notFoundHandler(req: Request, res: Response): void {
  logger.warn('Route not found', {
    method: req.method,
    path: req.path,
    ip: req.ip,
  });

  res.status(404).json({
    success: false,
    error: 'Route not found',
    message: `Cannot ${req.method} ${req.path}`,
  });
}

/**
 * Handle unhandled promise rejections
 */
export function handleUnhandledRejection(): void {
  process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
    logger.error('Unhandled Promise Rejection', {
      reason: reason?.message || reason,
      stack: reason?.stack,
      promise,
    });

    // In production, you might want to gracefully shutdown
    if (env.NODE_ENV === 'production') {
      // Give time for logging before exit
      setTimeout(() => {
        process.exit(1);
      }, 1000);
    }
  });
}

/**
 * Handle uncaught exceptions
 */
export function handleUncaughtException(): void {
  process.on('uncaughtException', (error: Error) => {
    logger.error('Uncaught Exception', {
      error: error.message,
      stack: error.stack,
    });

    // In production, you should gracefully shutdown
    if (env.NODE_ENV === 'production') {
      // Give time for logging before exit
      setTimeout(() => {
        process.exit(1);
      }, 1000);
    }
  });
}
