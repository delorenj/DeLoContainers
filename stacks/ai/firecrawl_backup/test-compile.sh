#!/bin/bash
cd /home/delorenj/docker/stacks/ai/firecrawl/apps/api
npm install typescript
npm install
npx tsc
echo "Compilation result: $?"
