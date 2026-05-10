BEGIN;

DROP TABLE IF EXISTS recipe_review_tag;

\echo 'recipe_review_tag table after drop'
SELECT to_regclass('public.recipe_review_tag') AS recipe_review_tag_table;

COMMIT;
