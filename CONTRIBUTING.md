# Contributing to Dart Backend Architecture

First off, thank you for considering contributing to this project! 🎉

This repository serves as a clean-architecture reference for building production-ready backends in Dart. Because of this, **consistency and architectural purity matter more than speed**. 

Please take a moment to read through these guidelines before opening a Pull Request. It helps us keep the codebase clean, predictable, and easy to maintain.

## 🛠 Development Setup

1. **Fork the repository** and clone your fork locally.
2. **Bootstrap the project**:
   ```bash
   make setup
   ```
3. **Start the dependencies**:
   ```bash
   # Using Docker (Highly Recommended)
   make up

   # Or natively (requires local Postgres/Redis/dbmate)
   make migrate
   make run
   ```
4. **Seed the database** (roles and default API key):
   ```bash
   make seed
   ```

## 🌿 Branches and Commits

* Please create a dedicated feature branch from `main` (e.g., `feat/add-new-route` or `fix/auth-bug`).
* Keep your commits focused, atomic, and easy to review.
* Use conventional commit messages in the imperative form:
  ```text
  feat(blog): add writer submit endpoint
  fix(auth): reject expired refresh token
  docs: update route table in README
  ```

## 🏛 Architecture Rules

To maintain the integrity of our architecture, please strictly adhere to the following rules:

1. **Explicit Wiring**: All concrete dependency wiring must happen in `lib/di/composition_root.dart`.
2. **No Service Locators**: Never use global service locator patterns (like `GetIt`). Always pass dependencies via constructors.
3. **Thin Handlers**: Keep your route handlers (`lib/routes/**`) extremely thin. They should only handle HTTP concerns (request parsing, validation, response formatting) and orchestrate calls to services.
4. **Business Logic**: All core business logic belongs in service classes (`lib/services/**`).
5. **Data Access**: Keep SQL and persistence details strictly inside repository implementations (`lib/database/repository/impl/**`).
6. **Interfaces**: Always depend on repository interfaces (`lib/database/repository/interfaces/**`), never on their concrete implementations.
7. **Typed Errors**: Use our sealed `ApiError` hierarchy instead of throwing raw `Exception`s.
8. **Versioning**: Keep API contracts versioned under `/v1`. Do not silently break existing routes.

## 💅 Coding Standards

* **Lints**: Ensure your code satisfies all rules in `analysis_options.yaml`.
* **Immutability**: Prefer `const`, `final`, and explicit typing wherever possible.
* **Imports**: Always use `package:` imports. Do not use relative imports across different packages or major directories.
* **Logging**: Avoid `print()`. Use the structured `AppLogger` instead so everything is traceable.
* **Responses**: Keep JSON structures consistent by utilizing our envelope helpers in `lib/core/response/**`.

## 🛡 Validation and Errors

* Always use **Zema** schemas for payload validation.
* Validate inputs explicitly by source (`body`, `query`, `param`, `header`) using our shared helpers.
* When something fails, return a typed failure via `ApiError` and let the middleware handle the HTTP response. Do not return ad-hoc error Maps.

## 🗄 Database and Migrations

* **One Migration Per Change**: Add exactly one migration file in `db/migrations/` per schema change.
* **Immutable History**: Never edit old migrations that have already been applied to shared environments.
* **Idempotency**: Write your migrations to be idempotent (`IF NOT EXISTS`, etc.) when possible.
* **Seeding**: If your changes require new mandatory data (like a new role), update `bin/db_seed.dart` to reflect this.

## 🧪 Testing

Before pushing your code, run the full test suite and quality checks:
```bash
make check
```

**Guidelines:**
* Add or update tests for any behavior changes.
* We strongly prefer unit tests for isolated service logic.
* Use `test/helpers/test_composition_root.dart` and `test/mocks/mocks.dart` to streamline testing.
* **Do not** require a real Database, Redis, or NATS instance for your unit tests. Mock external boundaries.

## ✅ Pull Request Checklist

Before hitting "Create PR", ensure you can check off these boxes:

- [ ] My code compiles and passes `dart analyze`.
- [ ] All tests pass locally (`dart test`).
- [ ] I have added tests to cover my new behavior or bug fix.
- [ ] I have not mixed unrelated refactoring into this PR.
- [ ] I have updated the documentation (`README.md`, route lists) if necessary.
- [ ] I have included a migration file if I changed the database schema.
- [ ] I have considered backward compatibility for any existing `/v1` endpoints.

## 🔐 Security and Secrets

* **NEVER** commit real secrets, API keys, or production passwords.
* **NEVER** commit `keys/private.pem` or `keys/public.pem`.
* Use `.env.example` as the single source of truth for required environment variables.
* If you discover a security vulnerability, please report it privately to the maintainers rather than opening a public issue.

---

*Thank you for helping make this architecture a robust and reliable reference for the Dart community!*
