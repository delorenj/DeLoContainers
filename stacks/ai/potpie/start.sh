#!/bin/bash
set -e

source .env

# Set development mode check
if [ "$isDevelopmentMode" = "enabled" ]; then
  echo "Running in development mode..."
else
  # Set up Service Account Credentials
  export GOOGLE_APPLICATION_CREDENTIALS="./service-account.json"

  # Check if the credentials file exists
  if [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
      echo "Error: Service Account Credentials file not found at $GOOGLE_APPLICATION_CREDENTIALS"
      echo "Please ensure the service-account.json file is in the current directory if you are working outside developmentMode"
  fi
fi

echo "Starting Docker Compose..."
docker compose down
docker compose build
docker compose up -d

# Wait for postgres to be ready
echo "Waiting for postgres to be ready..."
until docker exec potpie_postgres pg_isready -U ${PGUSER}; do
  echo "Postgres is unavailable - sleeping"
  sleep 2
done

echo "Postgres is up - applying database migrations"

# Verify virtual environment is active
if [ -z "$VIRTUAL_ENV" ]; then
 echo "No virtual environment is active. Creating a new one..."
 python -m venv venv
 source venv/bin/activate
fi

# Install python dependencies
echo "Installing Python dependencies..."
if ! pip install -r requirements.txt; then
 echo "Error: Failed to install Python dependencies"
 exit 1
fi

# Apply database migrations
alembic upgrade heads

echo "Starting momentum application..."
gunicorn --worker-class uvicorn.workers.UvicornWorker --workers 1 --timeout 1800 --bind 0.0.0.0:8001 --log-level debug app.main:app &

echo "Starting Celery worker"
# Start Celery worker with the proper queue name
celery -A app.celery.celery_app worker --loglevel=debug -Q "${CELERY_QUEUE_NAME}_process_repository" -E --concurrency=1 --pool=solo &
