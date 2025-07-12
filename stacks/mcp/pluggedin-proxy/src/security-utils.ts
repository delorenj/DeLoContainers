/**
 * Security utility functions for input validation and sanitization
 * Lightweight version for client-side MCP proxy
 */

import { debugError } from './debug-log.js';

/**
 * Validates a bearer token format
 * @param token - The token to validate
 * @returns true if valid, false otherwise
 */
export function validateBearerToken(token: string): boolean {
  // Bearer tokens should be 32-256 characters of alphanumeric, hyphen, underscore, or dot
  return /^[a-zA-Z0-9\-_.]{32,256}$/.test(token);
}

/**
 * Validates environment variable name
 * @param name - The environment variable name to validate
 * @returns true if valid, false otherwise
 */
export function validateEnvVarName(name: string): boolean {
  // Only allow alphanumeric characters and underscores
  return /^[A-Z0-9_]+$/i.test(name);
}

/**
 * Validates server UUID format (lightweight check)
 * @param uuid - The UUID to validate
 * @returns true if valid, false otherwise
 */
export function validateServerUuid(uuid: string): boolean {
  // Basic UUID format check - more permissive for client-side use
  return /^[0-9a-f-]{36}$/i.test(uuid) && uuid.length === 36;
}

/**
 * Validates and sanitizes tool names (lightweight)
 * @param name - The tool name to validate
 * @returns sanitized name or null if invalid
 */
export function validateToolName(name: string): string | null {
  if (!name || typeof name !== 'string') return null;
  
  // Basic validation - allow reasonable tool name characters
  if (name.length < 1 || name.length > 200) return null;
  
  return name; // Keep original for compatibility
}

/**
 * Validates URL with client-appropriate SSRF protection
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
    
    // For client-side proxy, allow localhost and private IPs for local MCP servers
    // Only block obviously dangerous patterns
    const hostname = parsed.hostname.toLowerCase();
    
    // Block only clearly malicious patterns, not legitimate local services
    const maliciousPatterns = [
      'metadata.google.internal',
      '169.254.169.254', // AWS/GCP metadata
      'metadata.azure.com',
      '[::]', // IPv6 all interfaces
      '0.0.0.0' // All interfaces
    ];
    
    return !maliciousPatterns.includes(hostname);
  } catch {
    return false;
  }
}

/**
 * Validates API base URL (permissive for client use)
 * @param url - The URL to validate
 * @returns true if valid, false otherwise
 */
export function validateApiUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return ['http:', 'https:'].includes(parsed.protocol);
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
    // Remove only the most dangerous shell metacharacters
    return String(arg)
      .replace(/[;&|`$()]/g, '') // Remove shell command separators
      .replace(/[\0\r\n]/g, ''); // Remove null bytes and newlines
  });
}

/**
 * Lightweight rate limiter for client-side use
 */
export class RateLimiter {
  private requests: number[] = [];
  private windowMs: number;
  private maxRequests: number;

  constructor(windowMs: number, maxRequests: number) {
    this.windowMs = windowMs;
    this.maxRequests = maxRequests;
  }

  checkLimit(): boolean {
    const now = Date.now();
    const windowStart = now - this.windowMs;

    // Remove old requests
    this.requests = this.requests.filter(time => time > windowStart);
    
    // Check if we're over the limit
    if (this.requests.length >= this.maxRequests) {
      return false;
    }
    
    // Add current request
    this.requests.push(now);
    return true;
  }

  reset(): void {
    this.requests = [];
  }
}

/**
 * Sanitizes error messages to prevent information disclosure
 * @param error - The error object or message
 * @returns Sanitized error message
 */
export function sanitizeErrorMessage(error: any): string {
  if (!error) return 'Unknown error occurred';
  
  let message = error instanceof Error ? error.message : String(error);
  
  // Remove only the most sensitive patterns
  const sensitivePatterns = [
    /password[=:]\s*[^\s]+/gi,
    /token[=:]\s*[^\s]+/gi,
    /Bearer\s+[^\s]+/gi,
    /api_key[=:]\s*[^\s]+/gi
  ];
  
  for (const pattern of sensitivePatterns) {
    message = message.replace(pattern, '[REDACTED]');
  }
  
  // Reasonable length limit
  if (message.length > 1000) {
    message = message.substring(0, 1000) + '...';
  }
  
  return message;
}

/**
 * Basic request size validation
 * @param data - The data to validate
 * @param maxSize - Maximum allowed size in bytes
 * @returns true if valid, false otherwise
 */
export function validateRequestSize(data: any, maxSize: number = 10 * 1024 * 1024): boolean {
  try {
    const size = JSON.stringify(data).length;
    return size <= maxSize;
  } catch {
    return false;
  }
}

/**
 * Lightweight timeout wrapper
 * @param operation - The async operation to wrap
 * @param timeoutMs - Timeout in milliseconds
 * @returns Promise that resolves with the operation result or rejects with timeout
 */
export function withTimeout<T>(
  operation: Promise<T>,
  timeoutMs: number
): Promise<T> {
  return Promise.race([
    operation,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('Operation timed out')), timeoutMs)
    )
  ]);
}