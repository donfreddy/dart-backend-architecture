-- migrate:up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE roles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(32) NOT NULL UNIQUE CHECK (code IN ('LEARNER', 'WRITER', 'EDITOR', 'ADMIN')),
    status      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO roles (code, status, created_at, updated_at)
VALUES
  ('LEARNER', TRUE, NOW(), NOW()),
  ('WRITER', TRUE, NOW(), NOW()),
  ('EDITOR', TRUE, NOW(), NOW()),
  ('ADMIN', TRUE, NOW(), NOW())
ON CONFLICT (code) DO NOTHING;

-- migrate:down
DROP TABLE IF EXISTS roles;
