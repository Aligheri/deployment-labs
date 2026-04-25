# mywebapp

Simple inventory service built with Spring Boot and PostgreSQL.

## Variant

N = 5, V2 = 2, V3 = 3, V5 = 1

- App: Simple Inventory (items with name and quantity)
- Config: `/etc/mywebapp/config.yaml`
- Database: PostgreSQL
- Port: 8080 (behind nginx on port 80)

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | / | list of endpoints (HTML only) |
| GET | /items | list all items |
| POST | /items?name=&quantity= | create item |
| GET | /items/{id} | get item by id |
| GET | /health/alive | liveness check |
| GET | /health/ready | readiness check (checks DB) |

All business endpoints support `Accept: application/json` and `Accept: text/html`.
Health endpoints are internal only (not exposed via nginx).

## Running locally

Requirements: Java 21, Docker

```bash
docker compose up db
./gradlew bootJar
```

Run with IntelliJ using profile `dev` and VM option `-Duser.timezone=UTC`.

Or run everything with Docker:
```bash
./gradlew bootJar && docker compose up --build
```

## Deployment

Tested on Ubuntu 24.04 LTS. Recommended: 1 vCPU, 1GB RAM, 10GB disk.

```bash
git clone <repo>
cd deployment-lab1
./gradlew bootJar
sudo bash deploy/install.sh
```

The script installs all dependencies, creates users, sets up PostgreSQL, configures nginx and systemd, and starts the service.

### Users created

| User | Password | Role |
|------|----------|------|
| student | 12345678 | sudo |
| teacher | 12345678 | sudo, must change on first login |
| operator | 12345678 | can manage mywebapp service and reload nginx |
| mywebapp | — | system user, runs the app |

### Checking the deployment

```bash
# service status
systemctl status mywebapp
systemctl status nginx

# test via nginx
curl http://<ip>/items
curl -X POST "http://<ip>/items?name=Monitor&quantity=2"

# health (internal only)
curl http://127.0.0.1:8080/health/ready
```