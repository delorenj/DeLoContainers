import { beforeAll, afterAll, afterEach } from 'vitest';

// Set test environment variables
beforeAll(() => {
  process.env.NODE_ENV = 'test';
  process.env.PLUGGEDIN_API_KEY = 'test-api-key';
  process.env.PLUGGEDIN_API_BASE_URL = 'http://localhost:3000';
});

// Clean up after each test
afterEach(() => {
  // Reset any mocks or state
});

// Clean up after all tests
afterAll(() => {
  // Any global cleanup
});