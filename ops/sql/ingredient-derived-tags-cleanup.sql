BEGIN;

CREATE TEMP TABLE canonical_recipe_tags (
    name TEXT PRIMARY KEY,
    sort_order INTEGER NOT NULL
) ON COMMIT DROP;

INSERT INTO canonical_recipe_tags (name, sort_order) VALUES
    ('고소함', 1),
    ('매콤함', 2),
    ('달달함', 3),
    ('상큼함', 4),
    ('마라강함', 5),
    ('감칠맛', 6),
    ('담백함', 7),
    ('마늘향', 8),
    ('짭짤함', 9),
    ('알싸함', 10),
    ('향긋함', 11);

DO $$
BEGIN
    IF to_regclass('public.recipe_review_tag') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.recipe_review_tag';
    END IF;
END $$;

DELETE FROM recipe_tag tag
WHERE NOT EXISTS (
    SELECT 1
    FROM canonical_recipe_tags canonical
    WHERE canonical.name = tag.name
)
AND NOT EXISTS (
    SELECT 1
    FROM sauce_recipe_tag recipe_tag_link
    WHERE recipe_tag_link.tag_id = tag.id
);

\echo 'remaining recipe tags'
SELECT tag.name
FROM recipe_tag tag
JOIN canonical_recipe_tags canonical ON canonical.name = tag.name
ORDER BY canonical.sort_order;

\echo 'non-canonical recipe tag rows'
SELECT tag.id, tag.name
FROM recipe_tag tag
WHERE NOT EXISTS (
    SELECT 1
    FROM canonical_recipe_tags canonical
    WHERE canonical.name = tag.name
)
ORDER BY tag.id;

\echo 'recipes with more than three derived tags'
SELECT recipe_id, count(*) AS tag_count
FROM sauce_recipe_tag
GROUP BY recipe_id
HAVING count(*) > 3;

DO $$
DECLARE
    review_tag_count BIGINT;
BEGIN
    IF to_regclass('public.recipe_review_tag') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM public.recipe_review_tag' INTO review_tag_count;
        RAISE NOTICE 'recipe_review_tag rows: %', review_tag_count;
    ELSE
        RAISE NOTICE 'recipe_review_tag table is absent';
    END IF;
END $$;

COMMIT;
