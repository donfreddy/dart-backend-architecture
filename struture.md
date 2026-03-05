# Structure

```text
dart-backend-architecture/
│
├── bin/
│   └── server.dart
│
├── lib/
│   ├── app.dart
│   ├── config.dart
│   │
│   ├── core/
│   │   ├── errors/
│   │   │   └── api_error.dart
│   │   ├── response/
│   │   │   └── api_response.dart
│   │   ├── jwt/
│   │   │   └── jwt_service.dart
│   │   ├── middleware/
│   │   │   ├── error_handler_middleware.dart
│   │   │   ├── tracing_middleware.dart
│   │   │   ├── auth_middleware.dart
│   │   │   ├── api_key_middleware.dart
│   │   │   ├── rate_limit_middleware.dart
│   │   │   └── cors_middleware.dart
│   │   ├── telemetry/
│   │   │   └── otel_setup.dart
│   │   └── logger.dart
│   │
│   ├── di/
│   │   └── composition_root.dart
│   │
│   ├── database/
│   │   ├── db_pool.dart
│   │   ├── model/
│   │   │   ├── user.dart
│   │   │   ├── user.freezed.dart          ← généré
│   │   │   ├── user.g.dart                ← généré
│   │   │   ├── blog.dart
│   │   │   ├── blog.freezed.dart          ← généré
│   │   │   ├── blog.g.dart                ← généré
│   │   │   ├── role.dart
│   │   │   ├── keystore.dart
│   │   │   └── api_key.dart
│   │   └── repository/
│   │       ├── interfaces/
│   │       │   ├── user_repo.dart
│   │       │   ├── blog_repo.dart
│   │       │   ├── keystore_repo.dart
│   │       │   └── api_key_repo.dart
│   │       └── impl/
│   │           ├── postgres_user_repo.dart
│   │           ├── postgres_blog_repo.dart
│   │           ├── postgres_keystore_repo.dart
│   │           └── postgres_api_key_repo.dart
│   │
│   ├── cache/
│   │   ├── cache_service.dart
│   │   ├── keys.dart
│   │   └── repository/
│   │       ├── blog_cache.dart
│   │       └── user_cache.dart
│   │
│   ├── messaging/
│   │   └── nats_service.dart
│   │
│   ├── workers/
│   │   └── crypto_worker.dart
│   │
│   ├── helpers/
│   │   ├── validator.dart
│   │   ├── permission.dart
│   │   └── security.dart
│   │
│   └── routes/
│       ├── router.dart
│       ├── access/
│       │   ├── login_handler.dart
│       │   ├── signup_handler.dart
│       │   ├── logout_handler.dart
│       │   ├── token_handler.dart
│       │   └── schema/
│       │       ├── login_schema.dart
│       │       └── signup_schema.dart
│       ├── blog/
│       │   ├── writer_handler.dart
│       │   ├── editor_handler.dart
│       │   ├── blog_detail_handler.dart
│       │   └── schema/
│       │       └── blog_schema.dart
│       ├── blogs/
│       │   └── list_handler.dart
│       └── profile/
│           └── profile_handler.dart
│
├── test/
│   ├── helpers/
│   │   ├── test_composition_root.dart
│   │   └── test_server.dart
│   ├── mocks/
│   │   └── mocks.dart
│   ├── unit/
│   │   ├── core/
│   │   │   ├── jwt_service_test.dart
│   │   │   └── error_handler_test.dart
│   │   └── services/
│   │       ├── auth_service_test.dart
│   │       └── blog_service_test.dart
│   └── integration/
│       ├── access/
│       │   ├── login_test.dart
│       │   └── signup_test.dart
│       └── blog/
│           └── blog_crud_test.dart
│
├── db/
│   ├── migrations/
│   │   ├── 20260101000001_create_roles.sql
│   │   ├── 20260101000002_create_users.sql
│   │   ├── 20260101000003_create_api_keys.sql
│   │   ├── 20260101000004_create_keystores.sql
│   │   └── 20260101000005_create_blogs.sql
│   └── schema.sql                          ← généré par dbmate dump
│
├── keys/
│   ├── private.pem
│   └── public.pem
│
├── .env.example
├── .env.test.example
├── .gitignore
├── .dockerignore
├── analysis_options.yaml
├── pubspec.yaml
├── Dockerfile
├── docker-compose.yml
└── .github/
    └── workflows/
        └── ci.yml
```
