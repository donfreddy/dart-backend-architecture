-- migrate:up
CREATE TABLE keystores (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    primary_key     TEXT NOT NULL,
    secondary_key   TEXT NOT NULL,
    status          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_keystores_client_id   ON keystores(client_id);
CREATE INDEX idx_keystores_primary_key ON keystores(primary_key);
CREATE INDEX idx_keystores_active      ON keystores(client_id) WHERE deleted_at IS NULL;

-- migrate:down
DROP TABLE IF EXISTS keystores;
