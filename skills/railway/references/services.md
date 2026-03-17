# Services & Infrastructure

All commands below assume the token is resolved from config. Always prefix with `RAILWAY_TOKEN=<token>`.

## Services

A Railway project can contain multiple services — your app, databases, Redis, workers, etc.

### List / Link Service

```bash
# Interactive service picker (links your local dir to a service)
RAILWAY_TOKEN=<token> railway service

# Check current linked service
RAILWAY_TOKEN=<token> railway status
```

### Add Services

```bash
# Interactive add (picks type)
RAILWAY_TOKEN=<token> railway add

# Add a specific database
RAILWAY_TOKEN=<token> railway add --database postgres
RAILWAY_TOKEN=<token> railway add --database redis
RAILWAY_TOKEN=<token> railway add --database mysql
RAILWAY_TOKEN=<token> railway add --database mongo
```

### Scale

```bash
# Scale a service (replicas, resources)
RAILWAY_TOKEN=<token> railway scale
```

### Delete Service

```bash
# Delete a service (destructive!)
RAILWAY_TOKEN=<token> railway delete -s service-name -y
```

## Databases

When you add a database via `railway add --database`, Railway provisions it and automatically injects connection variables (e.g., `DATABASE_URL`, `REDIS_URL`) into your other services.

### Connect to Database Locally

```bash
# Open a direct connection to a Railway database
RAILWAY_TOKEN=<token> railway connect postgres

# Or use railway run to get the connection string locally
RAILWAY_TOKEN=<token> railway run printenv DATABASE_URL
```

## Domains

```bash
# Add a custom domain
RAILWAY_TOKEN=<token> railway domain

# This opens an interactive flow to configure the domain
```

After adding a domain, Railway provides DNS records you need to set with your registrar.

## Volumes

```bash
# List volumes
RAILWAY_TOKEN=<token> railway volume list

# Add a volume
RAILWAY_TOKEN=<token> railway volume add

# Delete a volume (destructive — data is lost!)
RAILWAY_TOKEN=<token> railway volume delete
```

Volumes provide persistent storage that survives redeployments. Attach them to services that need durable data (e.g., SQLite, file uploads).

## SSH Access

```bash
# SSH into a running service
RAILWAY_TOKEN=<token> railway ssh

# SSH into a specific service
RAILWAY_TOKEN=<token> railway ssh -s api-server
```

## Project Management

```bash
# Create a new project
RAILWAY_TOKEN=<token> railway init

# Link current directory to an existing project
RAILWAY_TOKEN=<token> railway link

# Unlink current directory
RAILWAY_TOKEN=<token> railway unlink

# List all projects accessible by this account
RAILWAY_TOKEN=<token> railway list

# Open the project in Railway dashboard
RAILWAY_TOKEN=<token> railway open
```
