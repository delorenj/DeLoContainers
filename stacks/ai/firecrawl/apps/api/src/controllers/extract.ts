import { Request, Response } from "express";
import { Redis } from "ioredis";
import { authenticateUser } from "./auth";
import { RateLimiterMode } from "../../src/types";

export async function extractController(req: Request, res: Response) {
  try {
    // Authenticate the user
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.Scrape
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    // Get the URL parameter
    const url = req.query.url as string;
    if (!url) {
      return res.status(400).json({ error: "URL parameter is required" });
    }

    // Connect to Redis
    const redisUrl = process.env.REDIS_URL || "redis://redis:6379";
    const redis = new Redis(redisUrl);

    // Get data from Redis
    const key = `web-scraper-cache:${url}`;
    const data = await redis.get(key);
    await redis.quit();

    if (!data) {
      return res.status(404).json({ error: "Data not found for URL" });
    }

    // Return the data
    return res.json(JSON.parse(data));
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}

export async function listCachedController(req: Request, res: Response) {
  try {
    // Authenticate the user
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.Scrape
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    // Connect to Redis
    const redisUrl = process.env.REDIS_URL || "redis://redis:6379";
    const redis = new Redis(redisUrl);

    // List all cached URLs
    const keys = await redis.keys("web-scraper-cache:*");
    await redis.quit();

    // Format the keys to remove the prefix
    const urls = keys.map(key => key.replace("web-scraper-cache:", ""));

    // Return the list of URLs
    return res.json({ urls });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}

export async function exportDataController(req: Request, res: Response) {
  try {
    // Authenticate the user
    const { success, team_id, error, status } = await authenticateUser(
      req,
      res,
      RateLimiterMode.Scrape
    );
    if (!success) {
      return res.status(status).json({ error });
    }

    // Get the URL parameter
    const url = req.query.url as string;
    if (!url) {
      return res.status(400).json({ error: "URL parameter is required" });
    }

    // Connect to Redis
    const redisUrl = process.env.REDIS_URL || "redis://redis:6379";
    const redis = new Redis(redisUrl);

    // Get data from Redis
    const key = `web-scraper-cache:${url}`;
    const data = await redis.get(key);
    await redis.quit();

    if (!data) {
      return res.status(404).json({ error: "Data not found for URL" });
    }

    // Set headers for file download
    const filename = url.replace(/[^a-zA-Z0-9]/g, '_');
    res.setHeader('Content-Disposition', `attachment; filename=${filename}.json`);
    res.setHeader('Content-Type', 'application/json');

    // Return the data as a downloadable file
    return res.send(data);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}
