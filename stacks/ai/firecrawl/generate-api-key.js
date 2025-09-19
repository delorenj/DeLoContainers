#!/usr/bin/env node

// Simple API key generator for self-hosted Firecrawl
const crypto = require('crypto');

function generateApiKey() {
  // Generate a secure random key
  const apiKey = crypto.randomBytes(32).toString('hex');
  
  console.log('\n=============== Firecrawl Self-Hosted API Key ===============');
  console.log(`API Key: ${apiKey}`);
  console.log('\nUse this key with the Authorization header:');
  console.log(`Authorization: Bearer ${apiKey}`);
  console.log('\nExample curl command:');
  console.log(`curl -X POST http://localhost:3002/crawl \\
  -H "Authorization: Bearer ${apiKey}" \\
  -H "Content-Type: application/json" \\
  -d '{"url":"https://example.com"}'`);
  console.log('==============================================================\n');
}

generateApiKey();
