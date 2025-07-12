#!/bin/bash
# Script to run tests locally for development
# Tests are excluded from Docker builds to minimize footprint

echo "Running pluggedin-mcp tests locally..."
echo "Note: Tests are not included in Docker builds to keep the image lightweight"
echo ""

npm test