-- Widen the existing external_identity provider check for Apple login.
--
-- Use this in environments that created external_identity before APPLE was
-- added to AuthProvider. The old PostgreSQL check can remain KAKAO-only when
-- production runs with spring.jpa.hibernate.ddl-auto=none.

BEGIN;

ALTER TABLE external_identity
    DROP CONSTRAINT IF EXISTS external_identity_provider_check_v2;

ALTER TABLE external_identity
    ADD CONSTRAINT external_identity_provider_check_v2
    CHECK (provider IN ('KAKAO', 'APPLE')) NOT VALID;

ALTER TABLE external_identity
    VALIDATE CONSTRAINT external_identity_provider_check_v2;

ALTER TABLE external_identity
    DROP CONSTRAINT IF EXISTS external_identity_provider_check;

ALTER TABLE external_identity
    RENAME CONSTRAINT external_identity_provider_check_v2
    TO external_identity_provider_check;

COMMIT;

-- Verification:
--
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'external_identity'::regclass
--   AND conname = 'external_identity_provider_check';
--
-- Rollback is only safe before any APPLE rows exist:
--
-- BEGIN;
-- ALTER TABLE external_identity DROP CONSTRAINT IF EXISTS external_identity_provider_check;
-- ALTER TABLE external_identity
--     ADD CONSTRAINT external_identity_provider_check
--     CHECK (provider = 'KAKAO');
-- COMMIT;
