<p align="center">
  <img alt="Dart Backend Architecture" src="addons/github_assets/cover.svg">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Dart-3.3%2B-0175C2?logo=dart" alt="Dart 3.3+">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
</p>

<p align="center">
  Welcome to Dart Backend Architecture - a complete, production-ready blueprint for building a robust blogging platform (think Medium or FreeCodeCamp) entirely in Dart.<br>
  Powered by Shelf, PostgreSQL, and Redis.
</p>

<p align="center">
  <i>Inspired by the renowned AfterAcademy Node.js architecture, we've completely reimagined it from the ground up.<br>
  This project showcases everything that makes Dart an exceptional choice for modern backend development.</i>
</p>

## Why This Exists

If you've ever felt that most Dart backend tutorials stop right after printing "Hello World", this repository is for you. We wanted to provide the exact opposite: a **battle-tested, scalable architecture** for building observable APIs in Dart. It takes the battle-proven patterns used by applications serving over 10 million users in TypeScript, and translates them into elegant, idiomatic Dart.

Here’s what sets this project apart:

* **Pure Dart Idioms (No Framework Magic)**: We rely on constructor injection, sealed types, and pattern matching rather than heavy frameworks or code generation.
* **SQL-First with PostgreSQL**: We believe in explicit queries and real transactions. You won't find any leaky ORM or query builder abstractions here.
* **Non-Blocking Crypto**: Heavy tasks like BCrypt password hashing are seamlessly offloaded to background isolates, ensuring your event loop remains lightning fast.
* **Observable by Default**: With built-in OpenTelemetry tracing and structured logging, you can measure and monitor every single request out of the box.

## Our Tech Stack

| Category | Choice | Why We Chose It |
|---|---|---|
| Runtime | **Dart 3.3+** | Sound null safety, pattern matching, and sealed classes make business logic rock-solid. |
| HTTP | **shelf + shelf_router** | The official Dart middleware framework. It's clean, fast, and has zero magic. |
| Database | **PostgreSQL + postgres v3** | A true SQL-first experience with robust transactions and explicit queries. |
| Cache | **Redis** | Fast cache-aside strategies with built-in protection against cache stampedes. |
| Validation | **Zema** | Ensures our request payloads are strictly validated and type-safe. |
| Auth | **JWT RS256** | Secure authentication using access and refresh token rotation with proper keystore lifecycles. |
| Observability | **OpenTelemetry** | Distributed tracing, metrics, and structured logs right from the start. |
| Migrations | **dbmate** | Plain SQL migration files without the overhead of an ORM. |
| Tests | **test + mocktail** | The official Dart test runner paired with an intuitive mocking library. |

## Architecture

Our application is structured around a clear separation of concerns, ensuring data flows predictably from the network layer down to storage.

```mermaid
graph TD
    subgraph MW["Middleware Pipeline"]
        direction LR
        A[errorHandler] --> B[tracing] --> C[logging]
        C --> D[bodyLimit] --> E[securityHeaders]
        E --> F[rateLimit] --> G[cors] --> H[apiKey] --> I[router]
    end

    subgraph Routes["Routes"]
        R1[signup / login / logout / token]
        R2[blog / writer / editor / profile]
    end

    subgraph Services["Services"]
        S1[AuthService]
        S2[TokenService]
    end

    subgraph Repos["Repositories"]
        BR[(PostgresBlogRepo)]
        UR[UserRepo]
        KR[KeystoreRepo]
    end

    subgraph Storage["Storage"]
        PG[(PostgreSQL)]
        RD[(Redis)]
    end

    MW --> Routes
    Routes --> Services
    S1 --> S2
    Services --> Repos
    UR --> PG
    KR --> PG
    BR --> PG
    BR -.-> RD
```

## Project Structure

We've organized the codebase logically by feature and responsibility to keep things easy to navigate:

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
│   └── repository/             # Interfaces + Postgres impls
├── di/
│   └── composition_root.dart   # Single wiring point (no service locator)
├── crypto/                     # CryptoSync — BCrypt via Isolate.run()
│   └── crypto_sync.dart
├── routes/
│   ├── health_handler.dart     # /healthz + /readyz
│   └── v1/
│       ├── access/             # signup, login, logout, token
│       ├── blog/               # writer + editor handlers
│       ├── blogs/              # public endpoints
│       └── profile/            # user profile
├── services/                   # Application business logic
db/
└── migrations/                 # 5 SQL migration files
test/
├── unit/                       # AuthService, middleware, handler tests
└── integration/                # End-to-end route tests
```

## Quick Start

Ready to get your hands dirty? Here is the fastest way to get the server running locally.

### Prerequisites

* Dart SDK 3.3+ (or just Docker + Docker Compose, if you prefer containers)

### 1) Clone & Bootstrap

```bash
git clone https://github.com/donfreddy/dart-backend-architecture
cd dart-backend-architecture
dart run bin/setup.dart
```

The `setup.dart` script is your friendly helper. It will:
* Prompt for your project name to personalize the template
* Automatically rename the template package across all source files
* Generate a fresh RSA key pair (`keys/private.pem` and `keys/public.pem`)
* Create your `.env` file based on `.env.example`
* Fetch all necessary dependencies via `dart pub get`

### 2A) Run with Docker (Highly Recommended)

Using Docker is the easiest way to ensure all services (Postgres, Redis, OTel) are perfectly configured.

```bash
docker compose up --build

# First time only: Seed the database with roles and a default API key
docker compose exec api dart run bin/db_seed.dart
```

Your services are now running at:
| Service | URL |
|---|---|
| API | `http://localhost:8080` |
| Grafana / OTel | `http://localhost:3000` |

> **API Key** (seeded by default): `GCMUDiuY5a7WvyUNt9n3QztToSHzK7Uj`  
> Make sure to pass this via the `x-api-key` header on every request!

### 2B) Run Tests (Fully Isolated via Docker)

Want to run the test suite without messing up your development data? We've got you covered.

```bash
docker compose -f docker-compose.test.yml up --build --exit-code-from=tester
docker compose -f docker-compose.test.yml down -v
```

This spins up an isolated PostgreSQL instance running on `tmpfs` (in-memory) for blazing fast, ephemeral tests that are completely destroyed on teardown.

### 2C) Run Locally (No Docker)

If you prefer running things natively on your machine, you'll need PostgreSQL 16, Redis 7, and `dbmate` installed.

```bash
# Development
cp .env.example .env
dbmate --migrations-dir db/migrations up
dart run bin/db_seed.dart
dart run bin/server.dart

# Tests (using a separate test database)
cp .env.test.example .env.test
DATABASE_URL=postgres://dba_test:dba_test@localhost:5432/dba_test?sslmode=disable \
  dbmate --migrations-dir db/migrations up
DATABASE_URL=postgres://dba_test:dba_test@localhost:5432/dba_test?sslmode=disable \
  dart run bin/db_seed.dart
dart test
```

## Concurrency & Performance

Since our backend is primarily I/O-bound, we handle all incoming requests efficiently on a single main isolate. This keeps the architecture simple and highly performant.

To ensure the server never freezes during heavy computations—such as hashing passwords with BCrypt (~250ms)—we seamlessly offload these tasks to background isolates using `Isolate.run()`. This keeps the main event loop completely free and responsive for other users. On the other hand, lightning-fast operations like RSA JWT verification (<2ms) are executed directly on the main thread, as the cost of switching isolates would outweigh the benefits.

## Core Principles

We strictly adhere to a few foundational principles to keep the codebase clean, predictable, and highly maintainable:

* **Explicit Dependency Wiring**: We use a single `CompositionRoot` to assemble the application, making it easy to see exactly how components connect.
* **No Service Locators**: Dependencies are always explicitly passed through constructors. We never hide them behind global locators or singletons.
* **Sealed Error Model**: Every API error is part of a sealed `ApiError` hierarchy, ensuring that all errors map predictably and safely to their corresponding HTTP status codes.
* **Observable by Default**: Every request automatically generates structured logs and OpenTelemetry spans, giving you full visibility into your system's health.
* **SQL-First Approach**: By avoiding ORMs and query builders, we retain full control and transparency over our database interactions using raw, optimized SQL.

## API Reference

All our endpoints are neatly mounted under `/v1`.

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

## Request Lifecycle

Ever wondered what exactly happens when a user signs up? Here is the complete journey of a `POST /v1/signup/basic` request traversing through our system:

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
          → CryptoSync.hashPassword        # BCrypt (offloaded to background isolate)
          → UserRepo.create                # User + keystore in one transaction
          → TokenService.buildForExistingKeys
              → JwtService.encode × 2     # RSA RS256 sign
  → lib/core/response/shelf_response_x.dart   # JSON response helpers
```

## Response Format

To keep things predictable and easy to consume for clients, all endpoints return standard JSON envelopes paired with their appropriate HTTP status codes.

### Success (200)

```json
{
  "message": "Signup Successful",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Jane Doe",
      "email": "jane@example.com",
      "roles": ["LEARNER"]
    },
    "tokens": {
      "access_token": "<jwt>",
      "refresh_token": "<jwt>"
    }
  }
}
```

### Paginated (200)

```json
{
  "message": "ok",
  "data": {
    "items": [ ... ],
    "meta": {
      "total_items": 42,
      "current_page": 1,
      "items_per_page": 10
    }
  }
}
```

### Error (4xx/5xx)

```json
{
  "message": "Authentication failure"
}
```

*Note: Access token errors will also include an `instruction: refresh_token` header to help your frontend automatically handle session renewals.*

## Quality Gates

We enforce strict quality control to keep our codebase pristine:

```bash
dart format --set-exit-if-changed .
dart analyze
dart test
```

Our continuous integration pipeline automatically runs these checks on every push and pull request (see `.github/workflows/ci.yml`).

## Learn More

If you want to dive deeper into the architectural concepts behind this project, check out these excellent resources:

* [Design Node.js Backend Architecture like a Pro](https://afteracademy.com/article/design-node-js-backend-architecture-like-a-pro) - The original article that inspired this architecture.
* [Implement JWT Authentication with Access and Refresh Tokens](https://afteracademy.com/article/implement-json-web-token-jwt-authentication-using-access-token-and-refresh-token) - A deep dive into the security model.

## Project Status

This isn't just a toy project; it is a living reference architecture. The patterns you see here are actively maintained and currently powering production-scale applications.

---

If you find this project useful, **star the repo** on GitHub - it helps others discover it!

## License

MIT - see [LICENSE](LICENSE).
