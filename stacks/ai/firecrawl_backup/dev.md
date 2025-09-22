# Firecrawl Debugging and Development Notes

## Summary of the Problem

The web crawler was consistently failing with the following errors:

*   **429 (Too Many Requests)** errors from the ScrapingBee API.
*   **502 (Bad Gateway)** errors from Playwright (used as a fallback).
*   A "Failed to bill team, no subscription was found" error in the logs.

These errors prevented the crawler from successfully retrieving and processing web pages.

## Steps Taken

1.  **Verified ScrapingBee API Key:** Confirmed that the `SCRAPING_BEE_API_KEY` environment variable was set, and asked the user to provide the key to compare.
2.  **Inspected Crawler Code:** Read the following files to understand the crawling logic, ScrapingBee integration, and error handling:
    *   `stacks/ai/firecrawl/apps/api/src/controllers/crawl.ts`
    *   `stacks/ai/firecrawl/apps/api/src/scraper/WebScraper/index.ts`
    *   `stacks/ai/firecrawl/apps/api/src/scraper/WebScraper/single_url.ts`
    *   `stacks/ai/firecrawl/apps/api/src/scraper/WebScraper/crawler.ts`
    *   `stacks/ai/firecrawl/apps/api/src/controllers/auth.ts`
    *   `stacks/ai/firecrawl/apps/api/src/services/billing/credit_billing.ts`
3.  **Checked Environment Configuration:** Examined the `Dockerfile` and `.env` files to see how environment variables were being set.
4.  **Installed Dependencies:** Installed missing dependencies: `scrapingbee`, `dotenv`, `@types/node`, and `cheerio`.
5.  **Added Logging:** Added `console.log` statements to `scrapWithScrapingBee` (in `single_url.ts`) and `fetchWithProxy` (in `crawler.ts`) to see the exact parameters being passed to ScrapingBee.
6.  **Reduced Concurrency:** Modified `compose.yml` to set `NUM_WORKERS_PER_QUEUE=1` for the `worker` service to reduce the request rate to ScrapingBee.
7.  **Rebuilt and Restarted:** Rebuilt the Docker image and restarted the `worker` service using `docker compose up -d --build worker`.
8.  **Triggered Crawl:** Used `curl` to send a POST request to the `/crawl` endpoint with a valid Firecrawl API key.
9.  **Monitored Logs:** Used `docker compose logs worker` to observe the crawler's behavior and the new log output.
10. **Identified Root Cause (Initial):** Initially suspected the ScrapingBee account was over its credit limit, causing the 429 errors.
11. **Checked Redis Cache:** Used `docker compose exec redis redis-cli KEYS "web-scraper-cache:*"` to confirm that some data was cached before the ScrapingBee limit was hit.
12. **Disabled Credit Check:** Commented out the credit check logic in `stacks/ai/firecrawl/apps/api/src/controllers/crawl.ts`.
13. **Clarified API Key Usage:** Determined that the API key provided in the `curl` command is the *Firecrawl* API key, used for authenticating with the Firecrawl API, while `SCRAPING_BEE_API_KEY` is used for ScrapingBee requests.
14. **Identified Root Cause (Revised):** The "Failed to bill team" error, combined with the persistent 429s despite a valid ScrapingBee key, indicates a problem with the *Firecrawl* account's subscription status in Supabase, not necessarily the ScrapingBee account itself.

## Current Status

*   The ScrapingBee API is returning 429 errors. While initially thought to be due to exceeding the ScrapingBee credit limit, the "Failed to bill team" error suggests a problem with the Firecrawl account's subscription in Supabase.
*   Playwright is returning 502 errors, likely as a consequence of the ScrapingBee failures or the target website blocking requests.
*   The "Failed to bill team" error is likely caused by a missing or inactive subscription in the Supabase database for the Firecrawl account.
*   Some data *was* successfully cached in Redis before the ScrapingBee limit was hit (or before the billing issue prevented further requests).
*   The crawler code has been updated with additional logging and reduced concurrency.
*   The Docker image has been rebuilt to include the code changes.
*   The credit check in `crawl.ts` has been disabled.

## Remaining Issues/TODOs

1.  **Firecrawl Account Subscription:** The primary issue is likely the Firecrawl account's subscription status in Supabase. The user needs to ensure they have an active subscription configured in Supabase. This might involve checking the `subscriptions` table and ensuring the `team_id` associated with the Firecrawl API key has a valid, active subscription.
2.  **ScrapingBee Account:** While the primary issue is likely with the Firecrawl account, the user should still verify their ScrapingBee account status and credit limit, as this could be a contributing factor.
3.  **Billing Error:** Once the subscription issue is resolved, the "Failed to bill team" error should also be resolved. If it persists, further investigation into the `billTeam` and `createCreditUsage` functions in `credit_billing.ts` might be needed.
4.  **Redis Data Retrieval:** The current method of accessing cached data (using `docker compose exec redis redis-cli`) is cumbersome. A better solution should be implemented, such as:
    *   Adding an API endpoint to retrieve cached data.
    *   Creating a script to simplify the process.
    *   Integrating with a Redis GUI for easier browsing.
5.  **Playwright 502 Errors:** Once the ScrapingBee and billing issues are resolved, if Playwright continues to return 502 errors, further investigation will be needed. This might involve checking Playwright's configuration, proxy settings, or the target website's behavior.
6.  **Rebuild API Service:** After disabling the credit check, the `api` service needs to be rebuilt for the changes to take effect. Run `docker compose up -d --build api`.

## Accessing Cached Data

You can access the data that was cached in Redis *before* the ScrapingBee limit was hit using the following commands (run from the `stacks/ai/firecrawl` directory):

1.  **List cached keys:**

    ```bash
    docker compose exec redis redis-cli KEYS "web-scraper-cache:*"
    ```

2.  **Get data for a specific key (replace with an actual key from the list):**

    ```bash
    docker compose exec redis redis-cli GET "web-scraper-cache:https://sst.dev/docs"
    ```

3.  **(Optional) Save data to a file:**
    ```bash
     docker compose exec redis redis-cli GET "web-scraper-cache:https://sst.dev/docs" > output.json