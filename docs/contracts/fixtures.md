# Fixture Contracts

Fixtures define stable product context for backend tests and optional local backend seed data.

## Runtime Data Policy

- iOS runtime must not load fixture-backed, mock-backed, or hard-coded product records.
- iOS must load recipe, ingredient, tag, review, profile, and favorite data only through the live backend API in `docs/contracts/api.md`.
- Fixture JSON may be transformed into persisted backend seed data for local development, but the app still consumes it only after the backend serves it through HTTP.
- Any future offline cache must be populated from successful backend responses, not bundled fixture files.

## Canonical Fixture Groups

- `users`: normal user, high-review user, report-threshold user
- `recipes_curated`: famous sauce recipes
- `recipes_user_generated`: user-created sauce compositions without author-selected taste classification
- `ingredients_master`: sauce bar ingredients
- `reviews`: mixed rating distribution and review text
- `favorites`: member-saved recipes for My Profile

## Identity Rules

- IDs must be stable across test runs.
- Emails must be fake and reserved for test use.
- Fixture names should be readable enough for failing tests.
- Do not include real user data.

## First Draft Scope

Start with enough data to cover:

1. Anonymous user opens popular recipe list and detail.
2. Kakao-authenticated user creates a recipe.
3. Logged-in user leaves rating and review.
4. Hidden recipe is excluded from public list.

## Storage Format

Canonical shared fixtures start as JSON under `docs/fixtures/`.

Current file:

- `docs/fixtures/nugusauce-mvp.json`

The JSON is intentionally portable so backend tests and local seed flows can reuse the same product context. Backend integration tests may transform it into persisted entities during setup. iOS app targets must not bundle or decode this JSON directly.

## Required MVP Fixture Semantics

- `users` includes normal, high-review, report-threshold, and admin users.
- `recipes_curated` contains visible celebrity/creator-attributed famous sauce combinations and at least one hidden recipe.
- `recipes_user_generated` contains user-created recipes tied to fixture users and must not include `spiceLevel`, `richnessLevel`, or `tagIds`.
- `ingredients_master` contains stable Haidilao sauce bar ingredients.
- `ingredients_master[].category` is a physical ingredient grouping, not a taste
  classification. Allowed values are `sauce_paste`, `oil`, `vinegar_citrus`,
  `fresh_aromatic`, `dry_seasoning`, `sweet_dairy`, `topping_seed`, `protein`,
  and `other`.
- `tags` contains taste tags such as `고소함`, `매콤함`, `달달함`, `상큼함`.
- `reviews` contains mixed ratings and `tasteTagIds`; user-generated recipe taste classification comes from review tags, not author input.
- `reports` contains at least one report and must not expose reporter identity in public responses.
- `favorites` contains at least one saved recipe for a normal user.

## Sauce Seed Notes

- `ingredients_master` IDs 1-12 are the original MVP fixture IDs and must stay stable.
- `ingredients_master` IDs 13+ are the researched sauce-bar expansion needed to express celebrity-attributed combinations such as 건희 소스, 마크 소스, 필릭스 소스, 아이엔 소스, 우기 소스, 성찬 소스, 소희 소스, and 지수 특제 소스.
- Curated recipe descriptions are product-authored summaries, not copied source text.
- Do not add generic blog/news sauce recommendations to `recipes_curated`; curated defaults should be tied to a named celebrity/creator source or kept as user-generated/test data.
- Research notes and source links live in `.omx/context/sauce-seed-research-20260425.md`.
