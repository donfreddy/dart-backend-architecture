-- migrate:up
CREATE TABLE api_keys (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metadata    TEXT NOT NULL,
    key         VARCHAR(128) NOT NULL UNIQUE,
    version     INTEGER NOT NULL,
    status      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

CREATE INDEX idx_api_keys_key ON api_keys(key);
CREATE INDEX idx_api_keys_active ON api_keys(id) WHERE deleted_at IS NULL;

INSERT INTO api_keys (metadata, key, version, status, created_at, updated_at)
VALUES (
  'To be used by the xyz vendor',
  'GCMUDiuY5a7WvyUNt9n3QztToSHzK7Uj',
  1,
  TRUE,
  NOW(),
  NOW()
)
ON CONFLICT (key) DO NOTHING;

-- migrate:down
DROP TABLE IF EXISTS api_keys;
