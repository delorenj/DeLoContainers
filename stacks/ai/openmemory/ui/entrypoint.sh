#!/bin/sh
set -e

# Ensure the working directory is correct
cd /app

# For Next.js standalone builds, environment variables should be handled at build time
# The NEXT_PUBLIC_ variables are already baked into the build during docker build
# So we don't need to do runtime replacement

echo "Starting Next.js application..."

# Execute the container's main process (CMD in Dockerfile)
exec "$@"