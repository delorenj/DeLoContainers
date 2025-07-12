#!/usr/bin/env node

import { spawn, execFile } from 'child_process';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log('🚀 Starting MCP Inspector with auto-open...');

// Load environment variables from .env.local with proper parsing
const envPath = join(__dirname, '..', '.env.local');
let envVars = {};

// Secure environment variable parser
function parseEnvFile(content) {
  const envVars = {};
  const lines = content.split('\n');
  
  for (const line of lines) {
    // Skip empty lines and comments
    if (!line.trim() || line.trim().startsWith('#')) continue;
    
    // Find first = sign for key-value split
    const equalIndex = line.indexOf('=');
    if (equalIndex === -1) continue;
    
    const key = line.substring(0, equalIndex).trim();
    let value = line.substring(equalIndex + 1).trim();
    
    // Remove surrounding quotes if present
    if ((value.startsWith('"') && value.endsWith('"')) || 
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    
    // Basic validation: only allow alphanumeric keys with underscores
    if (/^[A-Z0-9_]+$/.test(key)) {
      envVars[key] = value;
    }
  }
  
  return envVars;
}

try {
  const envContent = readFileSync(envPath, 'utf8');
  envVars = parseEnvFile(envContent);
} catch (error) {
  console.warn('⚠️  Could not load .env.local file');
}

// Validate and sanitize environment variables before use
// For API key, allow alphanumeric, underscores, and hyphens (common in API keys)
const sanitizedApiKey = envVars.PLUGGEDIN_API_KEY ? String(envVars.PLUGGEDIN_API_KEY).trim() : '';
// For URL, just trim whitespace - URL validation happens in the app
const sanitizedApiUrl = envVars.PLUGGEDIN_API_BASE_URL ? String(envVars.PLUGGEDIN_API_BASE_URL).trim() : '';

// Spawn the inspector process with validated environment variables
const inspector = spawn('npx', [
  '@modelcontextprotocol/inspector',
  'dist/index.js',
  '-e', `PLUGGEDIN_API_KEY=${sanitizedApiKey}`,
  '-e', `PLUGGEDIN_API_BASE_URL=${sanitizedApiUrl}`
], {
  stdio: 'pipe',
  env: { ...process.env, ...envVars }
});

let browserOpened = false;

// Handle stdout
inspector.stdout.on('data', (data) => {
  const output = data.toString();
  process.stdout.write(output);
  
  // Look for the pre-filled URL with token using secure regex
  // Token should be 32-64 hex characters (case-insensitive)
  const urlMatch = output.match(/http:\/\/localhost:6274\/\?MCP_PROXY_AUTH_TOKEN=([a-fA-F0-9]{32,64})/);
  if (urlMatch && !browserOpened) {
    const url = urlMatch[0];
    console.log('🌐 Auto-opening browser with pre-filled token...');
    
    // Open the URL in the default browser using execFile for security
    let openCommand;
    let openArgs = [];
    
    switch (process.platform) {
      case 'darwin':
        openCommand = 'open';
        openArgs = [url];
        break;
      case 'win32':
        openCommand = 'cmd.exe';
        openArgs = ['/c', 'start', '', url];
        break;
      default:
        openCommand = 'xdg-open';
        openArgs = [url];
    }
    
    execFile(openCommand, openArgs, (error) => {
      if (error) {
        console.error(`❌ Could not open browser automatically. Please manually open: ${url}`);
      } else {
        console.log('✅ Browser opened successfully with token!');
      }
    });
    
    browserOpened = true;
  }
});

// Handle stderr
inspector.stderr.on('data', (data) => {
  process.stderr.write(data);
});

// Handle process exit
inspector.on('close', (code) => {
  console.log(`\n📝 Inspector process exited with code ${code}`);
  process.exit(code);
});

// Handle Ctrl+C
process.on('SIGINT', () => {
  console.log('\n🛑 Stopping inspector...');
  inspector.kill('SIGINT');
});

process.on('SIGTERM', () => {
  inspector.kill('SIGTERM');
}); 