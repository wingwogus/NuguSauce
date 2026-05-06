-- NuguSauce consent rollout.
-- Apply before deploying backend code that enforces CONSENT_001.

BEGIN;

CREATE TABLE IF NOT EXISTS policy_version (
    id BIGSERIAL PRIMARY KEY,
    policy_type VARCHAR(40) NOT NULL,
    version VARCHAR(64) NOT NULL,
    title VARCHAR(120) NOT NULL,
    url VARCHAR(512) NOT NULL,
    required BOOLEAN NOT NULL DEFAULT TRUE,
    active_from TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uk_policy_version_type_version UNIQUE (policy_type, version),
    CONSTRAINT ck_policy_version_policy_type CHECK (
        policy_type IN ('TERMS_OF_SERVICE', 'PRIVACY_POLICY', 'CONTENT_POLICY')
    )
);

CREATE TABLE IF NOT EXISTS member_policy_acceptance (
    id BIGSERIAL PRIMARY KEY,
    member_id BIGINT NOT NULL,
    policy_version_id BIGINT NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source VARCHAR(40) NOT NULL,
    CONSTRAINT uk_member_policy_acceptance_member_policy UNIQUE (member_id, policy_version_id),
    CONSTRAINT fk_member_policy_acceptance_member
        FOREIGN KEY (member_id) REFERENCES member(id),
    CONSTRAINT fk_member_policy_acceptance_policy_version
        FOREIGN KEY (policy_version_id) REFERENCES policy_version(id)
);

CREATE INDEX IF NOT EXISTS idx_member_policy_acceptance_member
    ON member_policy_acceptance(member_id);

INSERT INTO policy_version (policy_type, version, title, url, required, active_from)
VALUES
    (
        'TERMS_OF_SERVICE',
        '2026-05-01',
        '서비스 이용약관',
        'https://nugusauce.jaehyuns.com/legal/terms',
        TRUE,
        '2026-05-01T00:00:00Z'
    ),
    (
        'PRIVACY_POLICY',
        '2026-05-01',
        '개인정보 처리방침',
        'https://nugusauce.jaehyuns.com/legal/privacy',
        TRUE,
        '2026-05-01T00:00:00Z'
    ),
    (
        'CONTENT_POLICY',
        '2026-05-01',
        '콘텐츠/사진 권리 정책',
        'https://nugusauce.jaehyuns.com/legal/content-policy',
        TRUE,
        '2026-05-01T00:00:00Z'
    )
ON CONFLICT (policy_type, version) DO UPDATE
SET title = EXCLUDED.title,
    url = EXCLUDED.url,
    required = EXCLUDED.required,
    active_from = EXCLUDED.active_from;

COMMIT;

-- Rollback for a failed pre-enforcement rollout:
-- BEGIN;
-- DROP TABLE IF EXISTS member_policy_acceptance;
-- DROP TABLE IF EXISTS policy_version;
-- COMMIT;
