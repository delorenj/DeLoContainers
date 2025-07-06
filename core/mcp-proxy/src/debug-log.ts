/**
 * Debug logging utility that only outputs when not using STDIO transport
 * This prevents console output from interfering with the STDIO protocol
 */

const isStdioTransport = () => {
  // Check if we're running with STDIO transport (default) or another transport
  // We can detect this by checking if the --transport flag was set to something other than stdio
  const args = process.argv.slice(2);
  const transportIndex = args.findIndex(arg => arg === '--transport');
  if (transportIndex === -1) {
    // No --transport flag means default (stdio)
    return true;
  }
  const transportType = args[transportIndex + 1];
  return !transportType || transportType === 'stdio';
};

const useStdio = isStdioTransport();

export const debugLog = (...args: any[]) => {
  if (!useStdio) {
    console.log(...args);
  }
};

export const debugError = (...args: any[]) => {
  if (!useStdio) {
    console.error(...args);
  }
};