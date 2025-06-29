FROM node:18-alpine

WORKDIR /app

# Install git and other dependencies
RUN apk add --no-cache git

# Clone the ideogram repository
RUN git clone https://github.com/delorenj/ideogram-mcp-server.git .

# Install dependencies
RUN npm install

# Build the project
RUN npm run build

EXPOSE 8009

CMD ["node", "dist/index.js"]
