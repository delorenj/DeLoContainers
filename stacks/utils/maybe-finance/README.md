# Maybe Finance

This directory contains the Docker Compose setup for running the [Maybe Finance](https://github.com/maybe-finance/maybe) application.

## Setup

1. **Install Docker and Docker Compose.**

   Follow the official instructions to install [Docker Engine](https://docs.docker.com/engine/install/) and Docker Compose.

2. **Create a `.env` file.**

   Create a copy of the `.env.example` file and name it `.env`.

   ```bash
   cp .env.example .env
   ```

3. **Generate a `SECRET_KEY_BASE`.**

   Generate a secret key using one of the following commands:

   ```bash
   # Using openssl
   openssl rand -hex 64

   # Using bash
   head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' && echo
   ```

4. **Update your `.env` file.**

   Replace the placeholder values in your `.env` file with the generated `SECRET_KEY_BASE` and your desired `POSTGRES_PASSWORD`.

## Usage

1. **Start the application.**

   ```bash
   docker compose up -d
   ```

2. **Access the application.**

   Open your browser and navigate to `http://localhost:3000`.

3. **Create an account.**

   The first time you run the app, you will need to register a new account by clicking "create your account" on the login page.

## Updating

To update the application to the latest version, run the following commands:

```bash
docker compose pull
docker compose build
docker compose up --no-deps -d web worker
```
