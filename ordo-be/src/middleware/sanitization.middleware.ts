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
 * 
 * NOTE: Chat/AI routes are excluded from SQL keyword checks since natural language
 * messages may contain words like "create", "delete", "update" legitimately.
 */

// Routes that should skip strict SQL keyword checking (natural language input)
const NATURAL_LANGUAGE_ROUTES = [
  '/api/v1/chat',
  '/api/v1/conversations',
];

// Patterns that indicate potential SQL injection (STRICT - for form inputs)
const SQL_INJECTION_PATTERNS_STRICT = [
  /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|DECLARE)\b)/gi,
  /(--|\;|\/\*|\*\/)/g,
  /(\bOR\b.*=.*)/gi,
  /(\bAND\b.*=.*)/gi,
  /(\'|\")(\s)*(OR|AND)(\s)*(\d+)(\s)*=(\s)*(\d+)/gi,
];

// Patterns for natural language routes - only catch obvious injection attempts
const SQL_INJECTION_PATTERNS_RELAXED = [
  // Only catch combined SQL patterns that look like actual injection
  /(\bSELECT\b.*\bFROM\b)/gi,
  /(\bINSERT\b.*\bINTO\b)/gi,
  /(\bUPDATE\b.*\bSET\b)/gi,
  /(\bDELETE\b.*\bFROM\b)/gi,
  /(\bDROP\b.*\b(TABLE|DATABASE)\b)/gi,
  /(\bUNION\b.*\bSELECT\b)/gi,
  // SQL comment injection
  /(--\s*$|\/\*.*\*\/)/g,
  // Classic injection patterns
  /(\'|\")(\s)*(OR|AND)(\s)*(\d+)(\s)*=(\s)*(\d+)/gi,
  /(\bOR\b\s+1\s*=\s*1)/gi,
  /(\bAND\b\s+1\s*=\s*1)/gi,
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
 * @param value - The string to check
 * @param relaxed - Use relaxed patterns for natural language input
 */
function containsSQLInjection(value: string, relaxed: boolean = false): boolean {
  const patterns = relaxed ? SQL_INJECTION_PATTERNS_RELAXED : SQL_INJECTION_PATTERNS_STRICT;
  return patterns.some(pattern => {
    // Reset regex lastIndex to avoid issues with global flag
    pattern.lastIndex = 0;
    return pattern.test(value);
  });
}

/**
 * Check if a string contains XSS patterns
 */
function containsXSS(value: string): boolean {
  return XSS_PATTERNS.some(pattern => pattern.test(value));
}

/**
 * Recursively sanitize an object by checking all string values
 * @param obj - The object to check
 * @param path - Current path in the object for error reporting
 * @param relaxed - Use relaxed SQL patterns for natural language input
 */
function sanitizeObject(obj: any, path: string = 'body', relaxed: boolean = false): { isMalicious: boolean; type?: string; field?: string } {
  if (typeof obj === 'string') {
    if (containsSQLInjection(obj, relaxed)) {
      return { isMalicious: true, type: 'SQL_INJECTION', field: path };
    }
    if (containsXSS(obj)) {
      return { isMalicious: true, type: 'XSS', field: path };
    }
    return { isMalicious: false };
  }

  if (Array.isArray(obj)) {
    for (let i = 0; i < obj.length; i++) {
      const result = sanitizeObject(obj[i], `${path}[${i}]`, relaxed);
      if (result.isMalicious) {
        return result;
      }
    }
    return { isMalicious: false };
  }

  if (obj && typeof obj === 'object') {
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        const result = sanitizeObject(obj[key], `${path}.${key}`, relaxed);
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
    // Check if this is a natural language route (chat/AI)
    const isNaturalLanguageRoute = NATURAL_LANGUAGE_ROUTES.some(route => 
      req.path.startsWith(route) || req.originalUrl.includes(route)
    );
    
    // Check body
    if (req.body && Object.keys(req.body).length > 0) {
      const bodyResult = sanitizeObject(req.body, 'body', isNaturalLanguageRoute);
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

    // Check query parameters (always use strict mode for query params)
    if (req.query && Object.keys(req.query).length > 0) {
      const queryResult = sanitizeObject(req.query, 'query', false);
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

    // Check URL parameters (always use strict mode for URL params)
    if (req.params && Object.keys(req.params).length > 0) {
      const paramsResult = sanitizeObject(req.params, 'params', false);
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
