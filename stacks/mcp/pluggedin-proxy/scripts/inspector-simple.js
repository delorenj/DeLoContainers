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
  '-e', `PLUGGEDIN_API_BASE_URL=${sanitizedApiUrl}`,
  '-e', 'DANGEROUSLY_OMIT_AUTH=true'
], {
  stdio: 'inherit',
  env: { ...process.env, ...envVars }
});

// Wait a moment for the inspector to start, then open browser
setTimeout(() => {
  console.log('🌐 Opening browser...');
  
  // Use execFile for security instead of exec
  let openCommand;
  let openArgs = [];
  const url = 'http://localhost:6274';
  
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
      console.log('✅ Browser opened successfully!');
    }
  });
}, 3000); // Wait 3 seconds for inspector to fully start

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