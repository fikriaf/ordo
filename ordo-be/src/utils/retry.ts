import logger from '../config/logger';

/**
 * Retry configuration options
 */
export interface RetryOptions {
  maxRetries?: number;
  initialDelay?: number;
  maxDelay?: number;
  backoffMultiplier?: number;
  retryableErrors?: string[];
  onRetry?: (error: Error, attempt: number) => void;
}

/**
 * Default retry configuration
 */
const DEFAULT_OPTIONS: Required<RetryOptions> = {
  maxRetries: 3,
  initialDelay: 1000, // 1 second
  maxDelay: 10000, // 10 seconds
  backoffMultiplier: 2,
  retryableErrors: [
    'ECONNREFUSED',
    'ETIMEDOUT',
    'ENOTFOUND',
    'ENETUNREACH',
    'EAI_AGAIN',
    'ECONNRESET',
    'EPIPE',
    'NetworkError',
    'TimeoutError',
    'ServiceUnavailable',
  ],
  onRetry: () => {},
};

/**
 * Check if an error is retryable
 */
function isRetryableError(error: any, retryableErrors: string[]): boolean {
  // Check error code
  if (error.code && retryableErrors.includes(error.code)) {
    return true;
  }

  // Check error name
  if (error.name && retryableErrors.includes(error.name)) {
    return true;
  }

  // Check HTTP status codes (5xx errors are retryable)
  if (error.status && error.status >= 500 && error.status < 600) {
    return true;
  }

  if (error.statusCode && error.statusCode >= 500 && error.statusCode < 600) {
    return true;
  }

  // Check error message
  if (error.message) {
    const message = error.message.toLowerCase();
    if (
      message.includes('timeout') ||
      message.includes('network') ||
      message.includes('connection') ||
      message.includes('unavailable')
    ) {
      return true;
    }
  }

  return false;
}

/**
 * Calculate delay with exponential backoff
 */
function calculateDelay(
  attempt: number,
  initialDelay: number,
  maxDelay: number,
  backoffMultiplier: number,
): number {
  const delay = initialDelay * Math.pow(backoffMultiplier, attempt - 1);
  return Math.min(delay, maxDelay);
}

/**
 * Sleep for a specified duration
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry a function with exponential backoff
 * 
 * @param fn - The async function to retry
 * @param options - Retry configuration options
 * @returns The result of the function
 * @throws The last error if all retries fail
 * 
 * @example
 * ```typescript
 * const result = await retryWithBackoff(
 *   async () => {
 *     const response = await fetch('https://api.example.com/data');
 *     return response.json();
 *   },
 *   {
 *     maxRetries: 3,
 *     initialDelay: 1000,
 *     onRetry: (error, attempt) => {
 *       console.log(`Retry attempt ${attempt} after error: ${error.message}`);
 *     }
 *   }
 * );
 * ```
 */
export async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {},
): Promise<T> {
  const config = { ...DEFAULT_OPTIONS, ...options };
  let lastError: Error;

  for (let attempt = 1; attempt <= config.maxRetries + 1; attempt++) {
    try {
      return await fn();
    } catch (error: any) {
      lastError = error;

      // If this is the last attempt, throw the error
      if (attempt > config.maxRetries) {
        logger.error('All retry attempts failed', {
          attempts: attempt,
          error: error.message,
        });
        throw error;
      }

      // Check if error is retryable
      if (!isRetryableError(error, config.retryableErrors)) {
        logger.warn('Non-retryable error encountered', {
          error: error.message,
          code: error.code,
        });
        throw error;
      }

      // Calculate delay
      const delay = calculateDelay(
        attempt,
        config.initialDelay,
        config.maxDelay,
        config.backoffMultiplier,
      );

      // Log retry attempt
      logger.info('Retrying after error', {
        attempt,
        maxRetries: config.maxRetries,
        delay,
        error: error.message,
        code: error.code,
      });

      // Call onRetry callback
      config.onRetry(error, attempt);

      // Wait before retrying
      await sleep(delay);
    }
  }

  // This should never be reached, but TypeScript needs it
  throw lastError!;
}

/**
 * Retry a function with a simple retry count (no backoff)
 * 
 * @param fn - The async function to retry
 * @param maxRetries - Maximum number of retries
 * @returns The result of the function
 * @throws The last error if all retries fail
 */
export async function retry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
): Promise<T> {
  return retryWithBackoff(fn, {
    maxRetries,
    initialDelay: 0,
    backoffMultiplier: 1,
  });
}
