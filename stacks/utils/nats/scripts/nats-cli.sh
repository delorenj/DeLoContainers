#!/bin/bash
# Convenience script to run NATS CLI commands

if [ $# -eq 0 ]; then
    echo "Usage: $0 <nats-command>"
    echo "Examples:"
    echo "  $0 pub test.subject 'Hello World'"
    echo "  $0 sub test.subject"
    echo "  $0 stream ls"
    echo "  $0 consumer ls TEST_STREAM"
    exit 1
fi

docker exec -it nats-cli nats --server nats:4222 "$@"
