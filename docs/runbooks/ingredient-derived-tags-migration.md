# Ingredient-Derived Recipe Tags Migration

This runbook migrates existing environments from review-selected taste tags to
recipe-owned tags derived from ingredient composition.

## Scope

- Keep `recipe_tag` as the canonical tag table.
- Keep `sauce_recipe_tag` as the recipe-to-derived-tag relation.
- Stop using `recipe_review_tag`; leave it empty or drop it during an approved
  DDL window.
- Reviews keep only rating and text.

## Canonical Tags

`recipe_tag.name` must contain exactly:

1. `고소함`
2. `매콤함`
3. `달달함`
4. `상큼함`
5. `마라강함`
6. `감칠맛`
7. `담백함`
8. `마늘향`
9. `짭짤함`
10. `알싸함`
11. `향긋함`

Recipes may have at most three rows in `sauce_recipe_tag`.

## Preflight

1. Snapshot these tables:
   `recipe_tag`, `sauce_recipe`, `recipe_ingredient`, `sauce_recipe_tag`,
   `recipe_review`, and `recipe_review_tag` if it exists.
2. Confirm ingredient master data contains the names referenced by
   `RecipeTagDerivationPolicy`.
3. Run this during a maintenance window because search/filter semantics change
   immediately after `sauce_recipe_tag` is replaced.

## Backfill Outline

Use application code or an admin one-off job that calls
`RecipeTagDerivationPolicy.derive(...)` for every recipe. For PostgreSQL
environments, the checked-in SQL scripts mirror the policy:

- `ops/sql/ingredient-derived-tags-backfill.sql` upserts canonical tags and
  replaces `sauce_recipe_tag` with derived top-three tags. It intentionally
  leaves review-tag rows and obsolete tag rows in place so it can run safely
  before the new backend rollout completes.
- `ops/sql/ingredient-derived-tags-cleanup.sql` clears `recipe_review_tag` and
  deletes unreferenced non-canonical `recipe_tag` rows after the new backend is
  healthy.

1. Upsert the 11 canonical `recipe_tag` names.
2. Delete obsolete tag rows only after checking no other feature references
   them.
3. Clear `sauce_recipe_tag`.
4. For each recipe, load `recipe_ingredient` with ingredient name, amount, unit,
   and ratio.
5. Derive tag names through `RecipeTagDerivationPolicy`.
6. Insert the resulting top three tag IDs into `sauce_recipe_tag`.
7. Delete all rows from `recipe_review_tag` if the table exists.

## Verification

Run these checks after backfill:

```sql
select count(*) from recipe_tag;
select name from recipe_tag order by id;
select recipe_id, count(*) from sauce_recipe_tag group by recipe_id having count(*) > 3;
select count(*) from recipe_review_tag;
```

Expected:

- `recipe_tag` has 11 rows with the canonical names above.
- The `having count(*) > 3` query returns no rows.
- `recipe_review_tag` is zero rows, or the table is absent because it was
  dropped in the DDL window.

## Rollback

Rollback requires restoring the table snapshot because old review tag semantics
cannot be reconstructed from rating/text alone after `recipe_review_tag` is
cleared.
