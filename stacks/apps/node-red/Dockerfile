FROM nodered/node-red:4.1.3

# Install nodes needed for RabbitMQ + file watching
RUN npm install --unsafe-perm --no-update-notifier --no-fund \
    node-red-contrib-amqp \
    node-red-node-watch
