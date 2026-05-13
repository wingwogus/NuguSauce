-- Store encrypted Sign in with Apple refresh tokens for account deletion
-- revocation. Required because dev/prod run with spring.jpa.hibernate.ddl-auto=none.

BEGIN;

ALTER TABLE external_identity
    ADD COLUMN IF NOT EXISTS apple_refresh_token_ciphertext VARCHAR(2048);

ALTER TABLE external_identity
    ADD COLUMN IF NOT EXISTS apple_refresh_token_nonce VARCHAR(128);

ALTER TABLE external_identity
    ADD COLUMN IF NOT EXISTS apple_refresh_token_updated_at TIMESTAMPTZ;

COMMIT;

-- Verification:
--
-- SELECT column_name, data_type, character_maximum_length
-- FROM information_schema.columns
-- WHERE table_name = 'external_identity'
--   AND column_name IN (
--       'apple_refresh_token_ciphertext',
--       'apple_refresh_token_nonce',
--       'apple_refresh_token_updated_at'
--   )
-- ORDER BY column_name;
--
-- Rollback:
--
-- BEGIN;
-- ALTER TABLE external_identity
--     DROP COLUMN IF EXISTS apple_refresh_token_updated_at,
--     DROP COLUMN IF EXISTS apple_refresh_token_nonce,
--     DROP COLUMN IF EXISTS apple_refresh_token_ciphertext;
-- COMMIT;
