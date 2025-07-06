/**
 * Security utility functions for input validation and sanitization
 */

import { debugError } from './debug-log.js';

/**
 * Validates a bearer token format
 * @param token - The token to validate
 * @returns true if valid, false otherwise
 */
export function validateBearerToken(token: string): boolean {
  // Bearer tokens should be 32-256 characters of alphanumeric, hyphen, underscore, or dot
  // This covers most JWT, API key, and session token formats
  return /^[a-zA-Z0-9\-_.]{32,256}$/.test(token);
}

/**
 * Sanitizes error messages to prevent information disclosure
 * @param error - The error object
 * @param context - Context for the error (e.g., "API call", "Tool execution")
 * @returns Sanitized error message
 */
export function sanitizeErrorMessage(error: any, context: string): string {
  // Default safe error message
  let safeMessage = `${context} failed`;
  
  // For axios errors, only include HTTP status
  if (error.isAxiosError && error.response?.status) {
    safeMessage = `${context} failed (HTTP ${error.response.status})`;
  }
  
  // Log the full error internally for debugging
  debugError(`[${context}] Full error:`, error);
  
  return safeMessage;
}

/**
 * Validates URL to prevent SSRF attacks
 * @param url - The URL to validate
 * @returns true if valid, false otherwise
 */
export function validateUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    
    // Only allow http and https protocols
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return false;
    }
    
    // Prevent localhost and private IP access (SSRF protection)
    const hostname = parsed.hostname.toLowerCase();
    
    // Block localhost variations
    if (['localhost', '127.0.0.1', '[::1]', '0.0.0.0'].includes(hostname)) {
      return false;
    }
    
    // Block private IP ranges (simplified check)
    const ipPattern = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (ipPattern.test(hostname)) {
      const parts = hostname.split('.').map(Number);
      // 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
      if (parts[0] === 10 ||
          (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) ||
          (parts[0] === 192 && parts[1] === 168)) {
        return false;
      }
    }
    
    return true;
  } catch {
    return false;
  }
}

/**
 * Validates API base URL (allows localhost for development)
 * @param url - The URL to validate
 * @returns true if valid, false otherwise
 */
export function validateApiUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    
    // Only allow http and https protocols
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return false;
    }
    
    // For API URLs, we allow localhost and private IPs for development
    return true;
  } catch {
    return false;
  }
}

/**
 * Sanitizes command line arguments to prevent injection
 * @param args - Array of arguments
 * @returns Sanitized arguments
 */
export function sanitizeCommandArgs(args: string[]): string[] {
  return args.map(arg => {
    // Remove shell metacharacters and control characters
    return String(arg)
      .replace(/[;&|`$()<>\\]/g, '') // Remove shell metacharacters
      .replace(/[\0\r\n]/g, ''); // Remove null bytes and newlines
  });
}

/**
 * Validates environment variable name
 * @param name - Environment variable name
 * @returns true if valid, false otherwise
 */
export function validateEnvVarName(name: string): boolean {
  // Environment variable names should only contain letters, numbers, and underscores
  // and should start with a letter or underscore
  return /^[A-Za-z_][A-Za-z0-9_]*$/.test(name);
}

/**
 * Rate limiting helper for API calls
 */
export class RateLimiter {
  private requests: number[] = [];
  private readonly windowMs: number;
  private readonly maxRequests: number;
  
  constructor(windowMs: number = 60000, maxRequests: number = 60) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
  }
  
  /**
   * Check if request should be allowed
   * @returns true if allowed, false if rate limited
   */
  checkLimit(): boolean {
    const now = Date.now();
    // Remove old requests outside the window
    this.requests = this.requests.filter(time => now - time < this.windowMs);
    
    if (this.requests.length >= this.maxRequests) {
      return false;
    }
    
    this.requests.push(now);
    return true;
  }
}