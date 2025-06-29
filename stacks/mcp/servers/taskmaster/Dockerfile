FROM node:18-alpine

WORKDIR /app

# Install git and other dependencies
RUN apk add --no-cache git

# Clone the taskmaster repository
RUN git clone https://github.com/delorenj/taskmaster.git .

# Install dependencies
WORKDIR /app/taskmaster-mcp
RUN npm install

EXPOSE 8004

CMD ["node", "server.js"]
