# Self-Hosted Firecrawl Configuration

This document outlines the modifications made to run Firecrawl as a completely self-hosted service without requiring Supabase credit checking or billing, while still maintaining authentication via API keys.

## Modifications Made

1. **Credit and Billing Disabled**
   - Removed all credit checking from the crawl controller
   - Modified the credit billing services to bypass checks for self-hosted instances
   - Modified the authentication flow to validate API keys without Supabase

2. **Authentication Still Enabled**
   - API key authentication is still required
   - The API key is validated to ensure only authorized users can access your service
   - Set `USE_DB_AUTHENTICATION=false` to use this modified authentication flow

3. **ScrapingBee Configuration**
   - Modified to prioritize Playwright over ScrapingBee
   - ScrapingBee is now the last fallback option
   - You can still use ScrapingBee if you have an API key, but it's not required

## How to Use

### Step 1: Update Your Environment

Make sure your `.env` file has `USE_DB_AUTHENTICATION=false`.

### Step 2: Update Your Services

Run the provided script to update and restart your services:

```bash
chmod +x self-host-update.sh
./self-host-update.sh
```

### Step 3: Generate API Keys

You can generate secure API keys using the provided script:

```bash
node generate-api-key.js
```

Use the generated key in your requests:

```bash
curl -X POST http://localhost:3002/crawl \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'
```

## API Documentation

The Firecrawl API supports the following endpoints:

- `/crawl` - Start a new crawl job
- `/crawl/:jobId` - Get the status of a crawl job
- `/crawl/:jobId/results` - Get the results of a completed crawl job
- `/scrape` - Scrape a single URL
- `/batch-scrape` - Scrape multiple URLs in batch mode
- `/search` - Perform a web search and optionally scrape the results

For each request, include your API key in the Authorization header:
```
Authorization: Bearer YOUR_API_KEY
```

## Retrieving Results from Redis

To retrieve the cached data from Redis, you can use the following command:

```bash
docker compose exec redis redis-cli KEYS "web-scraper-cache:*"
```

Then, to retrieve a specific key:

```bash
docker compose exec redis redis-cli GET "web-scraper-cache:https://example.com"
```

## Troubleshooting

If you encounter any issues:

1. Check the logs: `docker compose logs -f api worker`
2. Verify your API key is being sent correctly
3. Ensure the Playwright service is running: `docker compose ps`
4. If using ScrapingBee, check your API key limit
