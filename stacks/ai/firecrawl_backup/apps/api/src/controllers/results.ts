import { Request, Response } from "express";
import Redis from "ioredis";
import { authenticateUser } from "./auth";
import { RateLimiterMode } from "../../src/types";

// Create Redis client
const redis = new Redis(process.env.REDIS_URL || "redis://redis:6379");

/**
 * Controller to get all cached URLs
 */
export async function getCachedUrlsController(req: Request, res: Response) {
  try {
    // Authenticate user
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.CrawlStatus
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    // Get all keys with the web-scraper-cache prefix
    const keys = await redis.keys("web-scraper-cache:*");
    
    // Extract the URLs from the keys
    const urls = keys.map(key => key.replace("web-scraper-cache:", ""));
    
    return res.json({ urls });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}

/**
 * Controller to get contents of a specific cached URL
 */
export async function getCachedContentController(req: Request, res: Response) {
  try {
    // Authenticate user
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.CrawlStatus
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    const url = req.params.url;
    if (!url) {
      return res.status(400).json({ error: "URL is required" });
    }
    
    // Decode the URL parameter
    const decodedUrl = decodeURIComponent(url);
    
    // Get the cache key
    const key = `web-scraper-cache:${decodedUrl}`;
    
    // Get the content from Redis
    const content = await redis.get(key);
    if (!content) {
      return res.status(404).json({ error: "Content not found" });
    }
    
    try {
      // Try to parse the content as JSON
      const parsedContent = JSON.parse(content);
      return res.json(parsedContent);
    } catch (e) {
      // If it's not valid JSON, return as plain text
      return res.send(content);
    }
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}

/**
 * Controller to export content as markdown, JSON or text
 */
export async function exportContentController(req: Request, res: Response) {
  try {
    // Authenticate user
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.CrawlStatus
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    const url = req.params.url;
    const format = req.params.format || 'json';
    
    if (!url) {
      return res.status(400).json({ error: "URL is required" });
    }
    
    // Decode the URL parameter
    const decodedUrl = decodeURIComponent(url);
    
    // Get the cache key
    const key = `web-scraper-cache:${decodedUrl}`;
    
    // Get the content from Redis
    const content = await redis.get(key);
    if (!content) {
      return res.status(404).json({ error: "Content not found" });
    }
    
    try {
      // Parse the content
      const parsedContent = JSON.parse(content);
      
      switch (format.toLowerCase()) {
        case 'markdown':
          if (parsedContent.markdown) {
            res.setHeader('Content-Type', 'text/plain');
            res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(decodedUrl)}.md"`);
            return res.send(parsedContent.markdown);
          }
          return res.status(404).json({ error: "Markdown not available for this URL" });
        
        case 'text':
          if (parsedContent.content) {
            res.setHeader('Content-Type', 'text/plain');
            res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(decodedUrl)}.txt"`);
            return res.send(parsedContent.content);
          }
          return res.status(404).json({ error: "Text not available for this URL" });
        
        case 'html':
          if (parsedContent.html) {
            res.setHeader('Content-Type', 'text/html');
            res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(decodedUrl)}.html"`);
            return res.send(parsedContent.html);
          }
          return res.status(404).json({ error: "HTML not available for this URL" });
        
        case 'json':
        default:
          res.setHeader('Content-Type', 'application/json');
          res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(decodedUrl)}.json"`);
          return res.send(JSON.stringify(parsedContent, null, 2));
      }
    } catch (e) {
      // If it's not valid JSON, return as plain text
      res.setHeader('Content-Type', 'text/plain');
      res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(decodedUrl)}.txt"`);
      return res.send(content);
    }
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}
