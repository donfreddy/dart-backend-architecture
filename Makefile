.PHONY: setup run seed migrate format analyze test test-docker test-docker-down \
        up down keys clean

# ── Project setup ───────────────────────────────────────────
setup:
	dart run bin/setup.dart

keys:
	openssl genrsa -out keys/private.pem 2048
	openssl rsa -in keys/private.pem -pubout -out keys/public.pem

# ── Local development ───────────────────────────────────────
migrate:
	dbmate --migrations-dir db/migrations up

seed:
	dart run bin/db_seed.dart

run:
	dart run bin/server.dart

# ── Docker ──────────────────────────────────────────────────
up:
	docker compose up --build

down:
	docker compose down

test-docker:
	docker compose -f docker-compose.test.yml up --build --abort-on-container-exit
	docker compose -f docker-compose.test.yml down -v

# ── Quality ─────────────────────────────────────────────────
format:
	dart format --set-exit-if-changed .

analyze:
	dart analyze

test:
	dart test

check: format analyze test

# ── Clean ───────────────────────────────────────────────────
clean:
	dart pub cache clean
	rm -rf .dart_tool/
