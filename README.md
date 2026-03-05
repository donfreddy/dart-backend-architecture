# Dart Backend Architecture

A production-ready, clean architecture blueprint for building scalable backend servers with Dart.

[![CI](https://github.com/you/dart-backend-architecture/actions/workflows/ci.yml/badge.svg)](https://github.com/you/dart-backend-architecture/actions/workflows/ci.yml)
[![Dart](https://img.shields.io/badge/Dart-3.3+-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-orange)](LICENSE)

---

## Purpose

This project is a reference implementation of Clean Architecture for the Dart
server ecosystem. Inspired by the [AfterAcademy](https://github.com/afteracademy/nodejs-backend-architecture-typescript)
Node.js pattern, it demonstrates how to build a blogging platform (Medium-like)
with a strict separation of concerns — business logic stays independent of the
database, the HTTP transport layer, and any external agency.

A reference architecture for a Dart backend — not a framework, not a generator.
Clone it, read it, adapt it. Every decision is explicit and documen

## Tech stack

- **Runtime** — Dart 3.3+ (AOT, Isolate Worker Pool)
- **HTTP Layer** — Shelf & shelf_router
- **Database** — PostgreSQL via `package:postgres` v3 (binary protocol, connection pool)
- **Cache** — Redis (cache-aside pattern)
- **Messaging** — NATS (Asynchronous event-driven communication)
- **Validation** — Zema (Schema-based validation, zero code-gen)
- **Auth** — JWT RS256, access + refresh tokens, role-based
- **DI** — Constructor injection, zero service locator
- **Errors** — Sealed classes, exhaustive switch, zero accidental 500
- **Observability** — OpenTelemetry (traces + metrics), structured JSON logs
- **Migrations** — dbmate, plain SQL, versioned by timestamp
- **Tests** — `package:test` + `mocktail`, zero database required for unit tests

---

## Project structure

```text
dart-backend-architecture/
├── bin/server.dart              # Entrypoint — spawns Isolates
├── lib/
│   ├── app.dart                 # Shelf Pipeline + middleware chain
│   ├── config.dart              # Env config, no code generation
│   ├── core/                    # Errors, responses, JWT, middleware, OTel
│   ├── di/composition_root.dart # Single wiring file — all concretions live here
│   ├── database/                # Pool, models, repository interfaces + impls
│   ├── cache/                   # Redis client, cache-aside, key definitions
│   ├── messaging/               # NATS service
│   ├── workers/                 # Isolate worker pool (crypto, CPU tasks)
│   ├── helpers/                 # Validator, permission guards
│   └── routes/                  # Handlers, schemas, router
├── test/
│   ├── mocks/                   # All mocks in one place
│   ├── helpers/                 # TestCompositionRoot, test server
│   ├── unit/                    # No database, no Docker
│   └── integration/             # Full HTTP stack via Docker Compose
├── db/migrations/               # Plain SQL migrations (dbmate)
├── keys/                        # RSA key pair (generated locally, never committed)
├── .env.example
└── docker-compose.yml
```

---

## Getting started

You can run this project **locally** or with **Docker**.
Docker is recommended — it starts the full stack (API, PostgreSQL, Redis, NATS,
Grafana) in a single command with no local setup required.

---

### Option 1 — Docker (recommended)

**Requirements:** Docker + Docker Compose

```bash
git clone https://github.com/donfreddy/dart-backend-architecture
cd dart-backend-architecture

# Copy env and generate RSA keys
cp .env.example .env
openssl genrsa -out keys/private.pem 2048
openssl rsa -in keys/private.pem -pubout -out keys/public.pem

# Start everything
docker-compose up --build
```

| Service                    | URL                     |
|----------------------------|-------------------------|
| API                        | <http://localhost:8080> |
| Grafana (traces + metrics) | <http://localhost:3000> |

To run the test suite inside Docker:

```bash
docker-compose run --rm app dart test
```

---

### Option 2 — Local

**Requirements:** Dart SDK 3.3+, PostgreSQL 16, Redis 7, NATS 2, dbmate

```bash
git clone https://github.com/donfreddy/dart-backend-architecture
cd dart-backend-architecture

# Copy env and fill in your local values
cp .env.example .env

# Generate RSA keys
openssl genrsa -out keys/private.pem 2048
openssl rsa -in keys/private.pem -pubout -out keys/public.pem

# Install dependencies
dart pub get

# Run migrations
dbmate up

# Start the server
dart run bin/server.dart
```

To run tests locally:

```bash
dart test
```

To run only unit tests (no infrastructure needed):

```bash
dart test test/unit/
```

---

## Environment variables

Copy `.env.example` to `.env` and fill in the values.

```bash
cp .env.example .env
```

| Variable               | Description                      | Default            |
|------------------------|----------------------------------|--------------------|
| `PORT`                 | HTTP port                        | `8080`             |
| `DATABASE_URL`         | PostgreSQL connection string     | —                  |
| `REDIS_URL`            | Redis connection string          | —                  |
| `NATS_URL`             | NATS connection string           | —                  |
| `JWT_PRIVATE_KEY_PATH` | Path to RSA private key          | `keys/private.pem` |
| `JWT_PUBLIC_KEY_PATH`  | Path to RSA public key           | `keys/public.pem`  |
| `OTEL_ENDPOINT`        | OpenTelemetry collector endpoint | —                  |
| `ENVIRONMENT`          | `development` / `production`     | `development`      |

---

## API

Full documentation is available via the Postman collection in `/addons`.

### Auth

```text
POST   /signup/basic      Create account
POST   /login/basic       Login, returns access + refresh tokens
DELETE /logout            Invalidate token pair
POST   /token/refresh     Rotate tokens
```

### Blogs

```text
GET    /blogs             List published blogs (public)
GET    /blogs/:id         Get blog detail (public)
POST   /blog              Create draft (WRITER role)
PUT    /blog/:id          Update draft (WRITER role)
PUT    /blog/:id/submit   Submit for review (WRITER role)
PUT    /blog/:id/publish  Publish (EDITOR role)
```

### Profile

```text
GET    /profile/my        Get own profile (authenticated)
```

### Request / Response format

Every response follows the same envelope:

```json
// Success
{
  "statusCode": "10000",
  "message": "Login successful",
  "data": { ... }
}

// Error
{
  "code": "AUTH_FAILURE",
  "statusCode": "10001",
  "message": "Authentication failure"
}

// Validation error
{
  "code": "VALIDATION_ERROR",
  "statusCode": "10001",
  "message": "Validation failed",
  "errors": {
    "email": ["must be a valid email address"],
    "password": ["must be at least 8 characters"]
  }
}
```

## Architecture decisions

| #  | Decision   | Choice                     | Rejected              | Reason                                   |
|----|------------|----------------------------|-----------------------|------------------------------------------|
| 1  | HTTP       | Shelf + shelf_router       | Dart Frog             | Less magic, explicit pipeline            |
| 2  | Database   | `postgres` v3 + Repository | Drift, ORM            | Drift is SQLite-first, ORM hides SQL     |
| 3  | DI         | Constructor injection      | GetIt, Provider       | Compile-time safety, no global state     |
| 4  | Multi-core | Isolates + `shared: true`  | Single isolate        | Native Dart model, memory isolation      |
| 5  | Errors     | Sealed classes             | Raw exceptions        | Exhaustive switch, zero accidental 500   |
| 6  | Migrations | dbmate, plain SQL          | Drift migrations      | Language-agnostic, readable, atomic      |
| 7  | Code gen   | None                       | Freezed, build_runner | AOT-friendly, readable, no build step    |
| 8  | Config     | `Platform.environment`     | envied                | No code generation needed                |
| 9  | Tests      | mocktail + test            | mockito               | Null-safe, no code generation            |
| 10 | OTel       | dartastic_opentelemetry    | Workiva OTel          | Only Dart SDK on track for CNCF donation |

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with your improvements. Here are some guidelines to keep in mind:

1. No service locator imports outside di/composition_root.dart.
2. All dependencies via final fields and constructor injection.
3. All domain errors extend ApiError — no raw throw Exception().
4. Unit tests use TestCompositionRoot — no real database, no Docker.
5. dart analyze --fatal-infos must pass with zero warnings.

## Find this project useful ? ❤️

If this helped you, consider giving it a ⭐ on GitHub.
It helps others discover it and motivates continued improvement.

![Star on GitHub](https://img.shields.io/github/stars/donfreddy/dart-backend-architecture?)

## License

Licensed under MIT. Check [LICENSE](LICENSE) for more info.
