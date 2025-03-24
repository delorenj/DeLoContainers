#!/bin/bash

# Stop all running containers
echo "Stopping all running containers..."
docker compose down

# Rebuild the API and worker services with new changes
echo "Rebuilding API and worker services..."
docker compose build api worker

# Start all services
echo "Starting all services..."
docker compose up -d

echo "Services have been updated and restarted."
echo "You can check the logs with: docker compose logs -f"
echo ""
echo "Authentication status: Using API key authentication without credit checks"
echo "Scraping fallback order: Playwright > Fetch > Fire-Engine > ScrapingBee"
echo ""
echo "To test your Firecrawl service, you can use: "
echo "curl -X POST http://localhost:3002/crawl -H \"Authorization: Bearer YOUR_API_KEY\" -H \"Content-Type: application/json\" -d '{\"url\":\"https://example.com\"}'"
