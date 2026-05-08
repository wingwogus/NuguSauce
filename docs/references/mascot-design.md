# NuguSauce Mascot Design Guide

Last updated: 2026-05-07

This document is the reusable art direction for NuguSauce ingredient mascots. When a future task asks to "make mascots", "generate ingredient characters", or "draw NuguSauce characters", use this guide unless the user explicitly asks for a different style.

## Core Idea

NuguSauce mascots are intentionally small, awkward, and low-status. They should feel cute, memorable, and slightly useless rather than heroic or polished.

The signature expression is an uppercase `N`-shaped mouth. This represents NuguSauce without adding labels or text.

## Source Of Truth

Use the real app ingredient master list:

- Fixture: `docs/fixtures/nugusauce-mvp.json`
- JSON path: `ingredients_master`
- Current count: 38 ingredients

Do not invent app ingredients when the request is "our app ingredients". Pull names from the fixture and preserve the fixture order unless the user asks for a curated subset.

Current ingredient order:

1. 참기름
2. 땅콩소스
3. 다진 마늘
4. 고수
5. 다진 고추
6. 해선장
7. 간장
8. 식초
9. 설탕
10. 파
11. 깨
12. 고추기름
13. 스위트 칠리소스
14. 땅콩가루
15. 고춧가루
16. 볶음 소고기장
17. 마라소스
18. 참깨소스
19. 굴소스
20. 중국식초
21. 흑식초
22. 와사비
23. 레몬즙
24. 소금
25. 맛소금
26. 연유
27. 들깨가루
28. 양파
29. 태국 고추
30. 다진 고기
31. 마라시즈닝
32. 청유 훠궈 소스
33. 버섯소스
34. 오향 우육
35. 매운 소고기 소스
36. 쪽파
37. 대파
38. 참깨가루

## Visual Rules

- Overall style: flat minimal Korean indie kawaii mascot.
- Mood: pathetic, timid, low-energy, slightly embarrassing, but cute.
- Shape: chunky rounded silhouettes, simple enough to read at app-icon size.
- Face: tiny black dot eyes plus a black uppercase `N` zigzag mouth.
- Mouth: the `N` must be part of the expression, not printed text or a logo label.
- Limbs: optional tiny useless feet or stubby arms; keep them minimal.
- Detail level: low. Use 1-2 ingredient-specific cues only.
- Background for concept sheets: warm off-white page with pastel rounded-square tiles.
- Rendering: flat color, subtle paper grain, tiny soft shadow.
- Text: no labels, captions, watermark, or readable text in the image.
- Avoid realism: no detailed food rendering, no complex props, no dramatic lighting.
- Avoid copying references: preserve the simple blob feeling, but make silhouettes original.

## Category Shape Grammar

Use these defaults when translating an ingredient into a mascot:

- `oil`: glossy droplet, puddle, or tiny oil ring.
- `sauce_paste`: squat blob, puddle, dab, squeeze mound, or sticky lump.
- `fresh_aromatic`: leaf lump, stump, paste mound, pepper curve, onion chunk, or herb bundle.
- `vinegar_citrus`: translucent droplet, sour splash, lemon-tinted drop, or thin wobbly blob.
- `sweet_dairy`: soft cream blob, sugar cube cluster, or pale sweet puddle.
- `topping_seed`: seed cluster, powder mound, dusty cloud, or crumb pile.
- `dry_seasoning`: powder mound, sprinkle pile, crystal cluster, or crumbly specks.
- `protein`: squat meat chunk or crumbly mound.

## Sheet Composition

For all 38 ingredients, generate four sheets:

- Sheet 1: ingredients 1-10, 5 columns x 2 rows.
- Sheet 2: ingredients 11-20, 5 columns x 2 rows.
- Sheet 3: ingredients 21-30, 5 columns x 2 rows.
- Sheet 4: ingredients 31-38, 4 columns x 2 rows.

For smaller explorations:

- 10 variants: 5 columns x 2 rows.
- 20 variants: 5 columns x 4 rows.
- 5 variants: 5 across or a loose 2-row grid.

Each mascot should sit centered in its own pastel rounded-square tile.

## Prompt Template

Use this template for ingredient sheets:

```text
Create NuguSauce ingredient mascot sheet {sheet_number} of {sheet_total}: exactly {count} original ingredient characters based on the app's real ingredient master list. Every character must have a facial mouth shaped like a clear uppercase 'N' zigzag line, used as an expression, not printed text. Style: flat minimal Korean indie kawaii mascots, intentionally pathetic, tiny dot eyes, awkward low-energy posture, chunky rounded silhouettes, sticker-ready, soft warm colors, subtle paper grain, tiny soft shadows.

Composition: {columns} columns x {rows} rows, each mascot centered in its own pastel rounded-square tile on a warm off-white background. No labels, no captions, no watermark, no readable text anywhere except the N-shaped mouth marks.

Characters in exact left-to-right, top-to-bottom order:
{numbered_ingredient_character_specs}

Design rules: each silhouette must be distinct at app-icon size; the uppercase N mouth must be black, small, and clearly visible; keep the characters simple and slightly useless, not heroic; no realistic food rendering.
```

## Character Spec Pattern

Each line in `{numbered_ingredient_character_specs}` should follow this shape:

```text
{fixture_id}) {ingredient_name}: {color/shape/body cue}, {one pathetic expression or posture cue}.
```

Examples:

```text
1) 참기름: glossy amber sesame oil droplet with tiny useless feet.
2) 땅콩소스: beige peanut sauce blob with small peanut-like bump.
3) 다진 마늘: pale garlic paste mound, lumpy and embarrassed.
7) 간장: black-brown soy sauce droplet, wobbly.
22) 와사비: pale green wasabi paste dab, tiny and pinched.
37) 대파: thicker leek / large green onion stump, pale green cylinder, timid.
```

## Reproducibility Checklist

Before generating:

- Confirm the request wants NuguSauce mascots, not production app asset replacement.
- Read `docs/fixtures/nugusauce-mvp.json` if using app ingredients.
- Preserve fixture order for full ingredient sets.
- Keep the uppercase `N` mouth in every character.
- Split 38 ingredients into 4 sheets so the designs stay readable.

After generating:

- Verify the expected number of sheets exists.
- Verify each sheet is a PNG and has non-zero dimensions.
- If the output is for brainstorming, it can remain under `$CODEX_HOME/generated_images`.
- If the output will be referenced by the app or repo docs, copy the selected final assets into the repo first.

## What To Avoid

- Do not add Korean or English labels inside the generated image.
- Do not make the mouth lowercase `n` for this ingredient system unless the user asks.
- Do not use a smile, frown, or normal line mouth as the main expression.
- Do not make detailed mascots with clothes, tools, chef hats, or story props.
- Do not make every ingredient the same blob shape; silhouette variety matters.
- Do not use dark, glossy, realistic product-shot styling.
- Do not replace checked-in iOS assets unless the user explicitly asks for production asset integration.
