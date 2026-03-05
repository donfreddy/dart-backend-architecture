-- Generated schema baseline (dbmate dump equivalent)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE roles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(32) NOT NULL UNIQUE CHECK (code IN ('LEARNER', 'WRITER', 'EDITOR', 'ADMIN')),
    status      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    name            VARCHAR(255) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    profile_pic_url TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE TABLE user_roles (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id     UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

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

CREATE TABLE blogs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255) NOT NULL,
    description     TEXT NOT NULL,
    text            TEXT,
    draft_text      TEXT,
    tags            TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    author_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    img_url         TEXT,
    blog_url        VARCHAR(255) NOT NULL UNIQUE,
    likes           INTEGER NOT NULL DEFAULT 0,
    score           DOUBLE PRECISION NOT NULL DEFAULT 0,
    is_submitted    BOOLEAN NOT NULL DEFAULT FALSE,
    is_draft        BOOLEAN NOT NULL DEFAULT TRUE,
    is_published    BOOLEAN NOT NULL DEFAULT FALSE,
    status          BOOLEAN NOT NULL DEFAULT TRUE,
    published_at    TIMESTAMPTZ,
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX idx_api_keys_key ON api_keys(key);
CREATE INDEX idx_api_keys_active ON api_keys(id) WHERE deleted_at IS NULL;
CREATE INDEX idx_keystores_client_id ON keystores(client_id);
CREATE INDEX idx_keystores_primary_key ON keystores(primary_key);
CREATE INDEX idx_keystores_active ON keystores(client_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_blogs_author_id ON blogs(author_id);
CREATE INDEX idx_blogs_blog_url ON blogs(blog_url);
CREATE INDEX idx_blogs_published ON blogs(is_published) WHERE status = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_blogs_updated_at ON blogs(updated_at DESC);
CREATE INDEX idx_blogs_title_desc_fts ON blogs USING GIN (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, '')));
