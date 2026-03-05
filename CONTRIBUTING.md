# Contributing

Thanks for contributing to this project.

This repository is a clean-architecture backend template, so consistency matters more than speed. Please read and follow the rules below before opening a PR.

## Development setup

1. Fork and clone your fork.
2. Bootstrap project:

```bash
dart run bin/setup.dart
```

3. Start dependencies (choose one):

```bash
# Docker
docker compose up --build
```

```bash
# Local
dbmate --migrations-dir db/migrations up
dart run bin/server.dart
```

4. (Optional) Seed roles + API key:

```bash
dart run bin/db_seed.dart
```

## Branch and commits

- Create a feature branch from `main`.
- Keep commits focused and atomic.
- Use clear commit messages (imperative form), e.g.:
  - `feat(blog): add writer submit endpoint`
  - `fix(auth): reject expired refresh token`
  - `docs: update route table in README`

## Architecture rules (must follow)

1. Keep concrete wiring in `lib/di/composition_root.dart`.
2. Do not use service locator patterns.
3. Keep handlers thin (`lib/routes/**`): validation + orchestration only.
4. Put business logic in services (`lib/services/**`).
5. Keep persistence details in repository implementations (`lib/database/repository/impl/**`).
6. Use repository interfaces for dependencies (`lib/database/repository/interfaces/**`).
7. Use typed `ApiError` variants instead of raw `Exception`.
8. Keep API contracts versioned under `/v1` (or future `/v2`), do not break existing routes silently.

## Coding standards

- Follow lints in `analysis_options.yaml`.
- Prefer `const`, `final`, and explicit types.
- Use `package:` imports (no relative imports across packages).
- Avoid `print`; use `AppLogger`.
- Keep code generation out of domain/application flow.
- Keep JSON and response envelopes consistent with `lib/core/response/**`.

## Validation and errors

- Use Zema schemas for request validation.
- Validate by source (`body`, `query`, `param`, `header`) through shared helpers.
- Return typed failures via `ApiError` + response helpers, not ad-hoc maps.

## Database and migrations

- Add one migration per schema change in `db/migrations/`.
- Never edit old migrations that are already applied in shared environments.
- Keep migrations idempotent when possible.
- If seed data changes, update `bin/db_seed.dart` accordingly.

## Tests

Run before pushing:

```bash
dart analyze
dart test
```

Guidelines:

- Add or update tests for behavior changes.
- Prefer unit tests for service logic.
- Use `test/helpers/test_composition_root.dart` and `test/mocks/mocks.dart`.
- Do not require real DB/Redis/NATS for unit tests.

## Pull request checklist

- [ ] Code compiles and passes `dart analyze`.
- [ ] Tests pass (`dart test`).
- [ ] New behavior is covered by tests.
- [ ] No unrelated refactors mixed in.
- [ ] API/documentation updated (`README.md`, route list, examples).
- [ ] Migration included for schema changes.
- [ ] Backward compatibility considered for `/v1` endpoints.

## Security and secrets

- Never commit real secrets.
- Never commit `keys/private.pem`.
- Use `.env.example` as source of expected env vars.
- Report security issues privately (do not open public exploit details in issues).
