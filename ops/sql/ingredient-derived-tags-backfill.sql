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

INSERT INTO recipe_tag (name)
SELECT canonical.name
FROM canonical_recipe_tags canonical
WHERE NOT EXISTS (
    SELECT 1
    FROM recipe_tag existing
    WHERE existing.name = canonical.name
);

CREATE TEMP TABLE tag_ingredient_weights (
    tag_name TEXT NOT NULL,
    ingredient_name TEXT NOT NULL,
    ingredient_weight NUMERIC NOT NULL
) ON COMMIT DROP;

INSERT INTO tag_ingredient_weights (tag_name, ingredient_name, ingredient_weight) VALUES
    ('고소함', '참기름', 1),
    ('고소함', '땅콩소스', 1),
    ('고소함', '참깨소스', 1),
    ('고소함', '깨', 1),
    ('고소함', '땅콩가루', 1),
    ('고소함', '들깨가루', 1),
    ('고소함', '참깨가루', 1),
    ('매콤함', '다진 고추', 1),
    ('매콤함', '고추기름', 1),
    ('매콤함', '고춧가루', 1),
    ('매콤함', '태국 고추', 1),
    ('매콤함', '매운 소고기 소스', 1),
    ('매콤함', '스위트 칠리소스', 1),
    ('달달함', '설탕', 1),
    ('달달함', '연유', 1),
    ('달달함', '스위트 칠리소스', 1),
    ('달달함', '해선장', 1),
    ('상큼함', '식초', 1),
    ('상큼함', '중국식초', 1),
    ('상큼함', '흑식초', 1),
    ('상큼함', '레몬즙', 1),
    ('마라강함', '마라소스', 1),
    ('마라강함', '마라시즈닝', 1),
    ('마라강함', '청유 훠궈 소스', 1),
    ('감칠맛', '간장', 1),
    ('감칠맛', '굴소스', 1),
    ('감칠맛', '버섯소스', 1),
    ('감칠맛', '볶음 소고기장', 1),
    ('감칠맛', '매운 소고기 소스', 1),
    ('감칠맛', '오향 우육', 1),
    ('감칠맛', '다진 고기', 1),
    ('감칠맛', '해선장', 1),
    ('마늘향', '다진 마늘', 1),
    ('짭짤함', '간장', 1),
    ('짭짤함', '소금', 1),
    ('짭짤함', '맛소금', 1),
    ('짭짤함', '굴소스', 1),
    ('짭짤함', '해선장', 1),
    ('알싸함', '와사비', 1),
    ('알싸함', '다진 마늘', 1),
    ('알싸함', '파', 1),
    ('알싸함', '쪽파', 1),
    ('알싸함', '대파', 1),
    ('알싸함', '양파', 1),
    ('알싸함', '다진 고추', 1),
    ('알싸함', '태국 고추', 1),
    ('향긋함', '고수', 1),
    ('향긋함', '파', 1),
    ('향긋함', '쪽파', 1),
    ('향긋함', '대파', 1),
    ('향긋함', '양파', 1);

DELETE FROM sauce_recipe_tag;

WITH normalized_ingredients AS (
    SELECT
        ri.recipe_id,
        i.name AS ingredient_name,
        CASE
            WHEN ri.ratio IS NOT NULL AND ri.ratio > 0 THEN ri.ratio
            WHEN ri.amount IS NOT NULL AND ri.amount > 0 THEN
                ri.amount * CASE btrim(coalesce(ri.unit, ''))
                    WHEN '티스푼' THEN 0.333333
                    WHEN '작은술' THEN 0.333333
                    WHEN '꼬집' THEN 0.05
                    ELSE 1
                END
            ELSE 0
        END AS normalized_weight
    FROM recipe_ingredient ri
    JOIN ingredient i ON i.id = ri.ingredient_id
),
recipe_totals AS (
    SELECT
        recipe_id,
        sum(normalized_weight) AS total_weight
    FROM normalized_ingredients
    WHERE normalized_weight > 0
    GROUP BY recipe_id
),
weighted_ingredients AS (
    SELECT
        normalized.recipe_id,
        normalized.ingredient_name,
        normalized.normalized_weight / totals.total_weight AS share
    FROM normalized_ingredients normalized
    JOIN recipe_totals totals ON totals.recipe_id = normalized.recipe_id
    WHERE normalized.normalized_weight > 0
),
base_scores AS (
    SELECT
        weighted.recipe_id,
        weights.tag_name,
        sum(weighted.share * weights.ingredient_weight) AS score
    FROM weighted_ingredients weighted
    JOIN tag_ingredient_weights weights ON weights.ingredient_name = weighted.ingredient_name
    GROUP BY weighted.recipe_id, weights.tag_name
),
strong_scores AS (
    SELECT
        recipe.id AS recipe_id,
        greatest(
            coalesce(max(base.score) FILTER (WHERE base.tag_name = '고소함'), 0),
            coalesce(max(base.score) FILTER (WHERE base.tag_name = '매콤함'), 0),
            coalesce(max(base.score) FILTER (WHERE base.tag_name = '달달함'), 0),
            coalesce(max(base.score) FILTER (WHERE base.tag_name = '마라강함'), 0)
        ) AS strong_score
    FROM sauce_recipe recipe
    LEFT JOIN base_scores base ON base.recipe_id = recipe.id
    GROUP BY recipe.id
),
light_scores AS (
    SELECT
        recipe.id AS recipe_id,
        coalesce(
            sum(weighted.share) FILTER (
                WHERE weighted.ingredient_name IN (
                    '간장',
                    '식초',
                    '중국식초',
                    '흑식초',
                    '레몬즙',
                    '고수',
                    '파',
                    '쪽파',
                    '대파',
                    '양파'
                )
            ),
            0
        ) AS light_score
    FROM sauce_recipe recipe
    LEFT JOIN weighted_ingredients weighted ON weighted.recipe_id = recipe.id
    GROUP BY recipe.id
),
combined_scores AS (
    SELECT recipe_id, tag_name, score
    FROM base_scores
    UNION ALL
    SELECT light.recipe_id, '담백함', light.light_score
    FROM light_scores light
    JOIN strong_scores strong ON strong.recipe_id = light.recipe_id
    WHERE strong.strong_score <= 0.20
      AND light.light_score >= 0.45
),
thresholded_scores AS (
    SELECT
        combined.recipe_id,
        combined.tag_name,
        combined.score,
        canonical.sort_order
    FROM combined_scores combined
    JOIN canonical_recipe_tags canonical ON canonical.name = combined.tag_name
    WHERE (
        combined.tag_name IN ('마늘향', '마라강함', '알싸함')
        AND combined.score >= 0.10
    ) OR (
        combined.tag_name = '담백함'
        AND combined.score >= 0.45
    ) OR (
        combined.tag_name NOT IN ('마늘향', '마라강함', '알싸함', '담백함')
        AND combined.score >= 0.15
    )
),
ranked_scores AS (
    SELECT
        recipe_id,
        tag_name,
        row_number() OVER (
            PARTITION BY recipe_id
            ORDER BY score DESC, sort_order ASC
        ) AS tag_rank
    FROM thresholded_scores
)
INSERT INTO sauce_recipe_tag (recipe_id, tag_id)
SELECT ranked.recipe_id, tag.id
FROM ranked_scores ranked
JOIN recipe_tag tag ON tag.name = ranked.tag_name
WHERE ranked.tag_rank <= 3
ORDER BY ranked.recipe_id, ranked.tag_rank;

\echo 'canonical recipe tags present'
SELECT tag.name
FROM recipe_tag tag
JOIN canonical_recipe_tags canonical ON canonical.name = tag.name
ORDER BY canonical.sort_order;

\echo 'recipes with more than three derived tags'
SELECT recipe_id, count(*) AS tag_count
FROM sauce_recipe_tag
GROUP BY recipe_id
HAVING count(*) > 3;

\echo 'derived recipe tag row count'
SELECT count(*) AS derived_recipe_tag_rows
FROM sauce_recipe_tag;

COMMIT;
