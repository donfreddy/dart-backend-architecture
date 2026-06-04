<p align="center">
  <img src="https://img.shields.io/badge/Dart-3.3%2B-0175C2?logo=dart" alt="Dart 3.3+">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
</p>

<h1 align="center">Dart Backend Architecture</h1>

<p align="center">
  A production-grade Dart backend blueprint: clean architecture, SQL-first persistence,<br>
  zero code generation, and CPU-bound work offloaded to isolates.
</p>

<p align="center">
  <i>Inspired by the AfterAcademy Node.js architecture, reimagined in pure Dart<br>
  with everything that makes Dart exceptional for backend development.</i>
</p>

## Why this exists

Most Dart backend examples stop at "hello world" with a framework. This repository is the opposite, a **battle-tested architecture** for building scalable, observable APIs in Dart, used by applications with 10M+ users in its original TypeScript form.

What makes it different:

* **Dart idioms, not framework magic**: constructor injection, sealed types, pattern matching, no code generation
* **SQL-first with PostgreSQL**: explicit queries, real transactions, no query builder abstraction leak
* **CPU-bound work in isolates**: BCrypt hashing and RSA JWT verification run on dedicated workers, never blocking the HTTP event loop
* **Observable by default**: OpenTelemetry tracing + structured logging, every request is measurable
* **Zero code generation**: what you see is what runs. No build_runner, no annotations, no surprises

## Tech stack

| Category | Choice | Why |
|---|---|---|
| Runtime | **Dart 3.3+** | Sound null safety, pattern matching, sealed classes |
| HTTP | **shelf + shelf_router** | Official Dart middleware framework, no magic |
| Database | **PostgreSQL + postgres v3** | SQL-first, transactions, explicit queries |
| Cache | **Redis** | Cache-aside with read-through decorator |
| Events | **NATS** | Async pub/sub, optional (NoOp fallback) |
| Validation | **Zema** | Type-safe schema validation |
| Auth | **JWT RS256** | Access + refresh token rotation, keystore lifecycle |
| Observability | **OpenTelemetry** | Distributed tracing + metrics + structured logs |
| Migrations | **dbmate** | SQL migration files, no ORM |
| Tests | **test + mocktail** | Official Dart test runner + mock library |

## Architecture at a glance

```mermaid
graph TD
    subgraph MW["Middleware Pipeline"]
        direction LR
        A[errorHandler] --> B[tracing] --> C[logging] --> D[bodyLimit] --> E[headers] --> F[rateLimit] --> G[cors] --> H[apiKey] --> I[router]
    end

    subgraph Routes["Routes"]
        R1[signup / login / logout / token]
        R2[blog / writer / editor / profile]
    end

    subgraph Services["Services"]
        S1[AuthService]
        S2[TokenService]
        S3[BlogService]
    end

    subgraph Repos["Repositories"]
        PG[(PostgreSQL · raw SQL)]
        subgraph CACHE["CachingBlogRepo (decorator)"]
            BR[BlogRepo · Postgres]
            BC[BlogCache · Redis]
        end
    end

    subgraph Workers["Isolate Workers"]
        W1[CryptoWorker · BCrypt]
        W2[JwtWorker · RSA verify]
    end

    NATS([Messaging · NATS · optional])

    MW --> Routes
    Routes --> Services
    S1 <--> S2
    S2 <--> S3
    Services --> Repos
    CACHE --> PG
    Repos --> Workers
    Workers -.-> NATS
```

## Project structure

```
lib/
├── app.dart                    # Shelf pipeline (middleware stack)
├── config.dart                 # Typed config from env vars
├── cache/                      # Redis client + cache repos
│   ├── cache_service.dart
│   └── repository/
├── core/                       # Shared primitives
│   ├── errors/                 # Sealed ApiError hierarchy
│   ├── jwt/                    # JwtService (encode/validate)
│   ├── middleware/             # 8 middleware: auth, rate-limit, CORS, etc.
│   ├── response/               # Consistent API envelope
│   └── telemetry/              # OTel SDK init/shutdown
├── database/
│   ├── db_pool.dart            # PostgreSQL connection pool
│   ├── model/                  # Data models
│   └── repository/             # Interfaces + impls + caching decorator
├── di/
│   └── composition_root.dart   # Single wiring point (no service locator)
├── messaging/                  # EventBus interface + NATS + NoOp
├── routes/
│   ├── health_handler.dart     # /healthz + /readyz
│   └── v1/
│       ├── access/             # signup, login, logout, token
│       ├── blog/               # writer + editor handlers
│       ├── blogs/              # public endpoints
│       └── profile/            # user profile
├── services/                   # Application business logic
└── workers/                    # Isolate-based workers
    ├── crypto_worker.dart      # BCrypt in dedicated isolate
    └── jwt_worker.dart         # RSA JWT verification in dedicated isolate

db/
└── migrations/                 # 5 SQL migration files
test/
├── unit/                       # AuthService, BlogService, middleware tests
└── integration/                # End-to-end route tests
```

## Quick start

### Prerequisites

* Dart SDK 3.3+ : or Docker + Docker Compose

### 1) Clone & bootstrap

```bash
git clone https://github.com/donfreddy/dart-backend-architecture
cd dart-backend-architecture
dart run bin/setup.dart
```

`setup.dart` will:
* Prompt for your project name
* Rename template package in all source files
* Generate RSA key pair (`keys/private.pem` + `keys/public.pem`)
* Create `.env` from `.env.example`
* Run `dart pub get`

### 2A) Run with Docker (recommended)

```bash
docker compose up --build
```

| Service | URL |
|---|---|
| API | `http://localhost:8080` |
| Grafana / OTel | `http://localhost:3000` |
| NATS monitor | `http://localhost:8222` |

### 2B) Run tests (Docker : isolated, no dev data touched)

```bash
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit
docker compose -f docker-compose.test.yml down -v
```

PostgreSQL runs on `tmpfs` (in-memory). Separate credentials. Destroyed on teardown.

### 2C) Run locally

Requirements: PostgreSQL 16, Redis 7, NATS 2, dbmate

```bash
# Dev
cp .env.example .env
dbmate --migrations-dir db/migrations up
dart run bin/db_seed.dart
dart run bin/server.dart

# Tests (separate DB)
cp .env.test.example .env.test
DATABASE_URL=postgres://dba_test:dba_test@localhost:5432/dba_test?sslmode=disable \
  dbmate --migrations-dir db/migrations up
DATABASE_URL=postgres://dba_test:dba_test@localhost:5432/dba_test?sslmode=disable \
  dart run bin/db_seed.dart
dart test
```

## How Dart improves on the original Node.js architecture

| Concern | Node.js (original) | Dart (this project) |
|---|---|---|
| **CPU-bound work** | Blocks event loop (bcrypt, JWT verify) | **Dedicated Isolate workers** : HTTP handled uncontested |
| **Error model** | `class extends Error` | **Sealed class hierarchy** with exhaustive pattern matching |
| **DB persistence** | MongoDB (Mongoose ODM) | **PostgreSQL + raw SQL** : ACID transactions, schema enforcement |
| **Repository pattern** | Single repo per entity | **Interface Segregation** : `BlogQueryRepo` / `BlogWriteRepo` separated |
| **Caching** | Embedded in service layer | **Decorator pattern** : `CachingBlogRepo` wraps Postgres repo transparently |
| **Dependency wiring** | Import-based coupling | **Composition Root** : single file wires everything |
| **Observability** | Console.log | **OpenTelemetry** : distributed tracing, metrics, structured logging |
| **Async messaging** | Not included | **NATS** with `NoOpEventBus` fallback (zero overhead when disabled) |
| **Type safety** | TypeScript (transpiled) | **Native Dart** : sound null safety at runtime, no build step |

## The Isolate advantage

JavaScript/Node.js runs on a single thread. Any CPU-bound operation blocks **everything** : including handling other HTTP requests. Dart's isolate model solves this natively.

This project runs two dedicated workers:

```
┌─ Main Isolate (HTTP) ─────────────────────┐
│  shelf router → services → repos          │
│  Non-blocking I/O only                    │
└───────────────────────────────────────────┘
         │                        ▲
         │  hash/verify            │  validate/decode
         ▼                        │
┌─ CryptoWorker ───────┐  ┌─ JwtWorker ───────────┐
│  BCrypt hashing       │  │  RSA RS256 verify     │
│  Constant-time dummy  │  │  Decode (no expiry)   │
│  hash for timing      │  │                       │
│  attack mitigation    │  │                       │
└───────────────────────┘  └───────────────────────┘
```

## Core principles

* **Zero code generation**: no build_runner, no annotations in domain/application code
* **Explicit dependency wiring**: single `CompositionRoot` as the composition boundary
* **No service locator**: dependencies are passed through constructors, never fetched
* **Sealed error model**: every `ApiError` subtype maps to a predictable HTTP status
* **Observable by default**: structured logs + OTel spans on every request
* **SQL-first**: no ORM, no query builder; raw SQL gives you full control

## API reference

All endpoints are mounted under `/v1`.

### Auth

| Method | Path | Role |
|---|---|---|
| `POST` | `/v1/signup/basic` | Public |
| `POST` | `/v1/login/basic` | Public |
| `DELETE` | `/v1/logout` | Authenticated |
| `POST` | `/v1/token/refresh` | Public |

### Blogs : Public

| Method | Path |
|---|---|
| `GET` | `/v1/blogs/url?endpoint=<slug>` |
| `GET` | `/v1/blogs/id/<id>` |
| `GET` | `/v1/blogs/tag/<tag>?pageNumber=1&pageItemCount=10` |
| `GET` | `/v1/blogs/author/id/<id>` |
| `GET` | `/v1/blogs/latest?pageNumber=1&pageItemCount=10` |
| `GET` | `/v1/blogs/similar/id/<id>` |

### Blogs : WRITER

| Method | Path |
|---|---|
| `POST` | `/v1/blogs/writer` |
| `PUT` | `/v1/blogs/writer/id/<id>` |
| `PUT` | `/v1/blogs/writer/submit/<id>` |
| `PUT` | `/v1/blogs/writer/withdraw/<id>` |
| `DELETE` | `/v1/blogs/writer/id/<id>` |
| `GET` | `/v1/blogs/writer/submitted/all` |
| `GET` | `/v1/blogs/writer/published/all` |
| `GET` | `/v1/blogs/writer/drafts/all` |
| `GET` | `/v1/blogs/writer/id/<id>` |

### Blogs : EDITOR

| Method | Path |
|---|---|
| `PUT` | `/v1/blogs/editor/publish/<id>` |
| `PUT` | `/v1/blogs/editor/unpublish/<id>` |
| `DELETE` | `/v1/blogs/editor/id/<id>` |
| `GET` | `/v1/blogs/editor/published/all` |
| `GET` | `/v1/blogs/editor/submitted/all` |
| `GET` | `/v1/blogs/editor/drafts/all` |
| `GET` | `/v1/blogs/editor/id/<id>` |

### Profile

| Method | Path | Role |
|---|---|---|
| `GET` | `/v1/profile/public/id/<id>` | Public |
| `GET` | `/v1/profile/my` | Authenticated |
| `PUT` | `/v1/profile` | Authenticated |

## Request lifecycle

Trace of `POST /v1/signup/basic` through the system:

```text
bin/server.dart
  → lib/app.dart                           # Pipeline assembly
      → errorHandlerMiddleware             # Catches ApiError, records OTel metric
      → tracingMiddleware                  # Starts OTel HTTP span
      → logRequests                        # Structured log line
      → bodyLimitMiddleware                # Rejects oversized payloads
      → securityHeadersMiddleware          # CSP, HSTS, X-Content-Type-Options
      → rateLimitMiddleware                # Redis sliding window
      → corsMiddleware
      → apiKeyMiddleware                   # Validates x-api-key header
  → lib/routes/router.dart
  → lib/routes/v1/router.dart
  → lib/routes/v1/access/signup_handler.dart
      → validateSchema(signupSchema)       # Zema body validation
      → AuthService.signup
          → UserRepo.findByEmail           # Duplicate check
          → TokenService.generateKey × 2  # Pre-generate access + refresh keys
          → CryptoWorker.hashPassword      # BCrypt in dedicated isolate
          → UserRepo.create                # User + keystore in one transaction
          → TokenService.buildForExistingKeys
              → JwtService.encode × 2     # RSA RS256 sign
  → lib/core/response/api_response.dart   # Success envelope
  → lib/core/response/shelf_response_x.dart
```

## Response format

### Success (200)

```json
{
  "status": "10000",
  "message": "Signup Successful",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Jane Doe",
      "email": "jane@example.com",
      "roles": ["LEARNER"]
    },
    "tokens": {
      "accessToken": "<jwt>",
      "refreshToken": "<jwt>"
    }
  }
}
```

### Error (4xx/5xx)

```json
{
  "status": "10001",
  "message": "Authentication failure"
}
```

### Validation error (400)

```json
{
  "status": "10001",
  "message": "Validation failed",
  "data": {
    "errors": {
      "email": ["Invalid email format"],
      "password": ["Must be at least 8 characters"]
    }
  }
}
```

Access token errors include the header `instruction: refresh_token`.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | API port |
| `MAX_REQUEST_BODY_BYTES` | `1048576` | Max payload size |
| `WORKER_COUNT` | `0` | Isolates per process (`0` = CPU count) |
| `DATABASE_URL` | - | PostgreSQL connection string |
| `DB_POOL_SIZE` | `20` | Max connections per process |
| `REDIS_URL` | - | Redis connection string |
| `NATS_URL` | `""` | NATS (empty = events disabled) |
| `JWT_PRIVATE_KEY_PATH` | `keys/private.pem` | RSA private key |
| `JWT_PUBLIC_KEY_PATH` | `keys/public.pem` | RSA public key |
| `JWT_PRIVATE_KEY_PEM` | `""` | Inline PEM (overrides path) |
| `JWT_PUBLIC_KEY_PEM` | `""` | Inline PEM (overrides path) |
| `JWT_ACCESS_TOKEN_EXPIRY` | `3600` | Access token TTL (seconds) |
| `JWT_REFRESH_TOKEN_EXPIRY` | `2592000` | Refresh token TTL (seconds) |
| `OTEL_ENDPOINT` | `""` | OTLP collector (empty = telemetry disabled) |
| `ENVIRONMENT` | `development` | `development`, `test`, or `production` |

## Quality gates

```bash
dart format --set-exit-if-changed .
dart analyze
dart test
```

CI runs on every push and PR (see `.github/workflows/ci.yml`).

## Project status

This is a living reference architecture. The code is used in production-scale applications and is actively maintained.

## License

MIT - see [LICENSE](LICENSE).
