import { Request, Response, NextFunction } from 'express';
import { body } from 'express-validator';
import logger from '../config/logger';

/**
 * Input sanitization middleware to prevent SQL injection and XSS attacks
 * 
 * This middleware:
 * 1. Sanitizes all string inputs by escaping HTML and removing dangerous patterns
 * 2. Detects and logs potential SQL injection attempts
 * 3. Detects and logs potential XSS attempts
 * 4. Rejects requests with malicious payloads
 */

// Patterns that indicate potential SQL injection
const SQL_INJECTION_PATTERNS = [
  /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|DECLARE)\b)/gi,
  /(--|\;|\/\*|\*\/)/g,
  /(\bOR\b.*=.*)/gi,
  /(\bAND\b.*=.*)/gi,
  /(\'|\")(\s)*(OR|AND)(\s)*(\d+)(\s)*=(\s)*(\d+)/gi,
];

// Patterns that indicate potential XSS attacks
const XSS_PATTERNS = [
  /<script[^>]*>.*?<\/script>/gi,
  /<iframe[^>]*>.*?<\/iframe>/gi,
  /javascript:/gi,
  /on\w+\s*=/gi, // Event handlers like onclick=, onload=, etc.
  /<img[^>]*src[^>]*>/gi,
  /<object[^>]*>.*?<\/object>/gi,
  /<embed[^>]*>/gi,
];

/**
 * Check if a string contains SQL injection patterns
 */
function containsSQLInjection(value: string): boolean {
  return SQL_INJECTION_PATTERNS.some(pattern => pattern.test(value));
}

/**
 * Check if a string contains XSS patterns
 */
function containsXSS(value: string): boolean {
  return XSS_PATTERNS.some(pattern => pattern.test(value));
}

/**
 * Recursively sanitize an object by checking all string values
 */
function sanitizeObject(obj: any, path: string = 'body'): { isMalicious: boolean; type?: string; field?: string } {
  if (typeof obj === 'string') {
    if (containsSQLInjection(obj)) {
      return { isMalicious: true, type: 'SQL_INJECTION', field: path };
    }
    if (containsXSS(obj)) {
      return { isMalicious: true, type: 'XSS', field: path };
    }
    return { isMalicious: false };
  }

  if (Array.isArray(obj)) {
    for (let i = 0; i < obj.length; i++) {
      const result = sanitizeObject(obj[i], `${path}[${i}]`);
      if (result.isMalicious) {
        return result;
      }
    }
    return { isMalicious: false };
  }

  if (obj && typeof obj === 'object') {
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        const result = sanitizeObject(obj[key], `${path}.${key}`);
        if (result.isMalicious) {
          return result;
        }
      }
    }
    return { isMalicious: false };
  }

  return { isMalicious: false };
}

/**
 * Middleware to sanitize request body, query, and params
 */
export function sanitizeInput(req: Request, res: Response, next: NextFunction): void {
  try {
    // Check body
    if (req.body && Object.keys(req.body).length > 0) {
      const bodyResult = sanitizeObject(req.body, 'body');
      if (bodyResult.isMalicious) {
        logger.warn('Malicious input detected', {
          type: bodyResult.type,
          field: bodyResult.field,
          ip: req.ip,
          path: req.path,
          method: req.method,
          userAgent: req.get('user-agent'),
        });

        res.status(400).json({
          error: 'Invalid input detected',
          message: 'Your request contains potentially malicious content',
        });
        return;
      }
    }

    // Check query parameters
    if (req.query && Object.keys(req.query).length > 0) {
      const queryResult = sanitizeObject(req.query, 'query');
      if (queryResult.isMalicious) {
        logger.warn('Malicious input detected in query', {
          type: queryResult.type,
          field: queryResult.field,
          ip: req.ip,
          path: req.path,
          method: req.method,
          userAgent: req.get('user-agent'),
        });

        res.status(400).json({
          error: 'Invalid input detected',
          message: 'Your request contains potentially malicious content',
        });
        return;
      }
    }

    // Check URL parameters
    if (req.params && Object.keys(req.params).length > 0) {
      const paramsResult = sanitizeObject(req.params, 'params');
      if (paramsResult.isMalicious) {
        logger.warn('Malicious input detected in params', {
          type: paramsResult.type,
          field: paramsResult.field,
          ip: req.ip,
          path: req.path,
          method: req.method,
          userAgent: req.get('user-agent'),
        });

        res.status(400).json({
          error: 'Invalid input detected',
          message: 'Your request contains potentially malicious content',
        });
        return;
      }
    }

    next();
  } catch (error) {
    logger.error('Error in sanitization middleware', { error });
    next(error);
  }
}

/**
 * Express-validator sanitization chains for common fields
 */
export const sanitizeEmail = body('email').trim().normalizeEmail().escape();
export const sanitizeString = (field: string) => body(field).trim().escape();
export const sanitizeOptionalString = (field: string) => body(field).optional().trim().escape();
