-- migrate:up
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

CREATE INDEX idx_blogs_author_id ON blogs(author_id);
CREATE INDEX idx_blogs_blog_url ON blogs(blog_url);
CREATE INDEX idx_blogs_published ON blogs(is_published) WHERE status = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_blogs_updated_at ON blogs(updated_at DESC);
CREATE INDEX idx_blogs_title_desc_fts ON blogs USING GIN (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, '')));

-- migrate:down
DROP TABLE IF EXISTS blogs;
