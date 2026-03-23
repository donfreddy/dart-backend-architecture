# Dart Backend Architecture

Production-ready backend architecture in Dart with explicit boundaries, SQL-first repositories, and zero code generation.

## Why this project

This repository is a practical blueprint for building scalable APIs in Dart without framework magic.
It is inspired by the AfterAcademy Node.js architecture and adapted to Dart idioms:

- clear separation between transport, application, and infrastructure
- explicit dependency wiring through one composition root
- typed domain errors and consistent API envelopes
- SQL-first persistence with PostgreSQL

## Core principles

- Zero code generation for domain/application code
- Clean architecture with constructor injection
- No service locator outside composition root
- Sealed error model and predictable error mapping
- Observable by default (structured logs + tracing)

## Tech stack

- Dart 3.3+
- `shelf` + `shelf_router`
- PostgreSQL (`package:postgres` v3)
- Redis (cache-aside)
- NATS (async events)
- Zema (validation) by [@meragix](https://github.com/meragix/zema)
- JWT RS256 (access + refresh)
- OpenTelemetry
- dbmate migrations
- `test` + `mocktail`

## Project layout

```text
dart-backend-architecture/
├── bin/
│   ├── db_seed.dart
│   ├── server.dart
│   └── setup.dart
├── db/
│   ├── migrations/
│   │   ├── 20260101000001_create_roles.sql
│   │   ├── 20260101000002_create_users.sql
│   │   ├── 20260101000003_create_api_keys.sql
│   │   ├── 20260101000004_create_keystores.sql
│   │   └── 20260101000005_create_blogs.sql
│   └── schema.sql
├── keys/
│   ├── instruction.md
│   ├── private.pem.example
│   └── public.pem.example
├── lib/
│   ├── app.dart                        # Shelf pipeline builder
│   ├── config.dart                     # Typed config from env / .env
│   ├── cache/
│   │   ├── cache_service.dart          # Redis client wrapper
│   │   ├── keys.dart                   # Cache key constants
│   │   └── repository/
│   │       ├── blog_cache.dart
│   │       └── user_cache.dart         # User profile + keystore caching
│   ├── core/
│   │   ├── app_info.dart               # Service name, version, namespace constants
│   │   ├── logger.dart
│   │   ├── request_context_keys.dart   # Shelf request context key constants
│   │   ├── errors/
│   │   │   └── api_error.dart          # Sealed error hierarchy + HTTP status mapping
│   │   ├── jwt/
│   │   │   └── jwt_service.dart        # RSA JWT encode/validate/decode (async via worker)
│   │   ├── middleware/
│   │   │   ├── api_key_middleware.dart
│   │   │   ├── auth_middleware.dart    # JWT validation + user/keystore resolution
│   │   │   ├── authorization_middleware.dart
│   │   │   ├── body_limit_middleware.dart
│   │   │   ├── cors_middleware.dart
│   │   │   ├── error_handler_middleware.dart  # Catches ApiError + emits OTel error counter
│   │   │   ├── rate_limit_middleware.dart     # Redis sliding window + OTel bypass counter
│   │   │   ├── schema.dart             # Shared middleware validation schemas
│   │   │   ├── security_headers_middleware.dart
│   │   │   └── tracing_middleware.dart # OTel HTTP span per request
│   │   ├── response/
│   │   │   ├── api_response.dart
│   │   │   └── shelf_response_x.dart
│   │   └── telemetry/
│   │       └── otel_setup.dart         # OTel SDK init/shutdown
│   ├── database/
│   │   ├── db_pool.dart
│   │   ├── model/
│   │   │   ├── api_key.dart
│   │   │   ├── blog.dart
│   │   │   ├── keystore.dart
│   │   │   ├── role.dart
│   │   │   └── user.dart
│   │   └── repository/
│   │       ├── caching_blog_repo.dart  # Decorator: read-through cache + write invalidation
│   │       ├── impl/
│   │       │   ├── postgres_api_key_repo.dart
│   │       │   ├── postgres_blog_repo.dart
│   │       │   ├── postgres_keystore_repo.dart
│   │       │   ├── postgres_role_repo.dart
│   │       │   └── postgres_user_repo.dart
│   │       └── interfaces/
│   │           ├── api_key_repo.dart
│   │           ├── blog_query_repo.dart  # ISP: read-only blog operations
│   │           ├── blog_repo.dart        # Combines BlogQueryRepo + BlogWriteRepo
│   │           ├── blog_write_repo.dart  # ISP: write-only blog operations
│   │           ├── keystore_repo.dart
│   │           ├── role_repo.dart
│   │           └── user_repo.dart
│   ├── di/
│   │   └── composition_root.dart       # Single wiring point for all dependencies
│   ├── helpers/
│   │   ├── permission.dart
│   │   ├── security.dart
│   │   └── validator.dart
│   ├── messaging/
│   │   ├── event_bus.dart              # Abstract interface: publish/ping/close
│   │   ├── nats_event_bus.dart         # EventBus backed by NATS
│   │   ├── nats_service.dart           # Raw NATS client wrapper
│   │   └── no_op_event_bus.dart        # No-op EventBus (NATS disabled)
│   ├── routes/
│   │   ├── health_handler.dart         # /healthz + /readyz probes
│   │   ├── router.dart
│   │   └── v1/
│   │       ├── router.dart
│   │       ├── access/
│   │       │   ├── login_handler.dart
│   │       │   ├── logout_handler.dart
│   │       │   ├── schema.dart
│   │       │   ├── signup_handler.dart
│   │       │   └── token_handler.dart
│   │       ├── blog/
│   │       │   ├── blog_detail_handler.dart
│   │       │   ├── editor_handler.dart
│   │       │   ├── schema.dart
│   │       │   └── writer_handler.dart
│   │       ├── blogs/
│   │       │   └── list_handler.dart
│   │       └── profile/
│   │           ├── profile_handler.dart
│   │           └── schema.dart
│   ├── services/
│   │   ├── auth_service.dart           # Signup, login, logout, refresh — credential concerns only
│   │   ├── blog_service.dart
│   │   └── token_service.dart          # JWT issuance, rotation, revocation + keystore lifecycle
│   └── workers/
│       ├── crypto_worker.dart          # BCrypt hashing in a dedicated isolate
│       └── jwt_worker.dart             # RSA JWT verification in a dedicated isolate
├── test/
│   ├── helpers/
│   │   └── test_composition_root.dart
│   ├── integration/
│   │   └── access_routes_test.dart
│   ├── mocks/
│   │   └── mocks.dart
│   └── unit/
│       ├── middleware/
│       │   ├── body_limit_middleware_test.dart
│       │   └── rate_limit_middleware_test.dart
│       ├── routes/
│       │   └── health_handler_test.dart
│       └── services/
│           ├── auth_service_test.dart
│           └── blog_service_test.dart
├── .env.example
├── .gitignore
├── .github/
│   └── workflows/
│       └── ci.yml
├── analysis_options.yaml
├── Dockerfile
├── docker-compose.yml
├── pubspec.yaml
└── README.md
```

## Quick start

### 1) Bootstrap project (recommended)

Requirements: Dart SDK 3.3+

```bash
git clone https://github.com/donfreddy/dart-backend-architecture
cd dart-backend-architecture
dart run bin/setup.dart
```

`bin/setup.dart` will:

- ask for project name/description
- replace template package name in source files
- generate `keys/private.pem` and `keys/public.pem` (if missing)
- create `.env` from `.env.example` (if missing)
- run `dart pub get`

If you want to keep the original package name unchanged, skip this script and run setup manually.

### 2A) Run with Docker

Requirements: Docker + Docker Compose

```bash
docker compose up --build
```

Services:

- API: `http://localhost:8080`
- Grafana/OTel UI: `http://localhost:3000`
- NATS monitor: `http://localhost:8222`

### 2B) Run locally

Requirements: PostgreSQL 16, Redis 7, NATS 2, dbmate

```bash
dbmate --migrations-dir db/migrations up
dart run bin/server.dart
```

Optional seed data (roles + vendor API key):

```bash
dart run bin/db_seed.dart
```

## Environment variables

Copy `.env.example` to `.env`.

| Variable                   | Description                                               |
|----------------------------|-----------------------------------------------------------|
| `PORT`                     | API port                                                  |
| `MAX_REQUEST_BODY_BYTES`   | Max allowed request payload size in bytes                 |
| `WORKER_COUNT`             | Isolates per process (0 = auto by CPU count)              |
| `DATABASE_URL`             | PostgreSQL connection string                              |
| `DB_PORT`                  | Postgres published port (docker convenience)              |
| `DB_POOL_SIZE`             | Max Postgres connections per process                      |
| `REDIS_URL`                | Redis connection string                                   |
| `REDIS_PORT`               | Redis published port (docker convenience)                 |
| `NATS_URL`                 | NATS connection string (empty = events disabled)          |
| `NATS_PORT`                | NATS published port (docker convenience)                  |
| `JWT_PRIVATE_KEY_PATH`     | RSA private key file path                                 |
| `JWT_PUBLIC_KEY_PATH`      | RSA public key file path                                  |
| `JWT_PRIVATE_KEY_PEM`      | RSA private key PEM content (alternative to path)         |
| `JWT_PUBLIC_KEY_PEM`       | RSA public key PEM content (alternative to path)          |
| `JWT_ACCESS_TOKEN_EXPIRY`  | Access token TTL in seconds                               |
| `JWT_REFRESH_TOKEN_EXPIRY` | Refresh token TTL in seconds                              |
| `OTEL_ENDPOINT`            | OTLP collector endpoint (empty = telemetry disabled)      |
| `ENVIRONMENT`              | `development` or `production`                             |

## API base path

All endpoints are mounted under:

- `/v1`

## Routes

### Auth

- `POST /v1/signup/basic`
- `POST /v1/login/basic`
- `DELETE /v1/logout`
- `POST /v1/token/refresh`

### Blogs (public)

- `GET /v1/blogs/url?endpoint=<slug>`
- `GET /v1/blogs/id/<id>`
- `GET /v1/blogs/tag/<tag>?pageNumber=1&pageItemCount=10`
- `GET /v1/blogs/author/id/<id>`
- `GET /v1/blogs/latest?pageNumber=1&pageItemCount=10`
- `GET /v1/blogs/similar/id/<id>`

### Blogs (WRITER role)

- `POST /v1/blogs/writer`
- `PUT /v1/blogs/writer/id/<id>`
- `PUT /v1/blogs/writer/submit/<id>`
- `PUT /v1/blogs/writer/withdraw/<id>`
- `DELETE /v1/blogs/writer/id/<id>`
- `GET /v1/blogs/writer/submitted/all`
- `GET /v1/blogs/writer/published/all`
- `GET /v1/blogs/writer/drafts/all`
- `GET /v1/blogs/writer/id/<id>`

### Blogs (EDITOR role)

- `PUT /v1/blogs/editor/publish/<id>`
- `PUT /v1/blogs/editor/unpublish/<id>`
- `DELETE /v1/blogs/editor/id/<id>`
- `GET /v1/blogs/editor/published/all`
- `GET /v1/blogs/editor/submitted/all`
- `GET /v1/blogs/editor/drafts/all`
- `GET /v1/blogs/editor/id/<id>`

### Profile

- `GET /v1/profile/public/id/<id>`
- `GET /v1/profile/my`
- `PUT /v1/profile`

## Response format

Success envelope:

```json
{
  "status": "10000",
  "message": "Login success",
  "data": {}
}
```

Error envelope:

```json
{
  "status": "10001",
  "message": "Authentication failure"
}
```

Access token error responses include header:

- `instruction: refresh_token`

## Quality gates

```bash
dart analyze
dart test
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

MIT — see [LICENSE](LICENSE).
