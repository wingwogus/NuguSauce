# The Design System: Culinary Editorial

## 1. Overview & Creative North Star: "The Culinary Atelier"
This design system moves away from the clinical, "boxed-in" feel of standard social apps. Our Creative North Star is **The Culinary Atelier**—a high-end, editorial experience that treats sauce-making as an art form.

To achieve a premium yet accessible feel, we reject the rigid, symmetrical grid in favor of **Intentional Asymmetry**. We use large-scale typography and overlapping elements to mimic the layout of a boutique food magazine. The digital experience should feel as tactile and appetizing as the sauce itself, using depth and fluid motion to guide the user's "palate."

---

## 2. Colors: Tonal Depth & Warmth
Our palette is rooted in the heat of the hotpot and the luxury of the dining experience. We utilize a "Tonal-First" approach to UI structure.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined solely through background color shifts. Use `surface-container-low` (#F3F3F3) sections against a `surface` (#F9F9F9) background to create containment.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers.
- **Base:** `surface` (#f9f9f9)
- **Subtle Depth:** Use `surface_container` (#eeeeee) for secondary content areas.
- **High Focus:** Use `surface_container_lowest` (#ffffff) for card backgrounds to make them "pop" against the off-white base.

### Dark Mode Contract
Dark mode is a first-class presentation mode, not an afterthought. The app supports three global appearance settings: `System`, `Light`, and `Dark`. The selected setting must be applied at the app shell via SwiftUI `preferredColorScheme`; feature screens should not set their own local color scheme.

Use semantic `SauceColor` tokens everywhere so the same screen composition survives both appearances:
- **Dark Base:** `surface` (#15100f)
- **Dark Subtle Depth:** `surface_container_low` (#1e1716)
- **Dark High Focus:** `surface_container_lowest` (#302421)
- **Dark Text:** `on_surface` (#f8edeb) and `on_surface_variant` (#dcc0bb)
- **Dark Accent:** keep Haidilao red vivid through `primary` / `primary_container`, adjusted brighter for dark contrast.

Do not hardcode white card backgrounds, black text, or light-only placeholder gradients in feature views. Exceptions are deliberate brand assets and contrast-safe foregrounds such as white text on red primary CTAs.

### The Glass & Gradient Rule
To prevent the UI from feeling "flat," use **Glassmorphism** for floating action buttons or ingredient overlays.
- **Glass Token:** Use `surface` at 80% opacity with a `24px` backdrop blur.
- **Signature Gradients:** For primary CTAs, use a subtle linear gradient from `primary` (#b7000c) to `primary_container` (#e60012) at a 135-degree angle to simulate the sheen of a fresh chili oil.

---

## 3. Typography: Editorial Authority
We pair the geometric confidence of **Plus Jakarta Sans** with the humanist clarity of **Manrope**.

- **Display & Headlines (Plus Jakarta Sans):** These are our "flavor notes." Use `display-lg` for hero recipe titles. Don't be afraid of tight letter-spacing (-2%) to create a punchy, brand-forward look.
- **Body & Labels (Manrope):** Optimized for the "kitchen environment." Ingredients and ratios use `body-lg` with increased line-height (1.6) to ensure readability while the user is actively cooking.
- **The "Ratio" Hierarchy:** Ingredient measurements (e.g., "2 tbsp") should use `title-md` in a bold weight to stand out from the ingredient name (`body-md`), creating a clear scanning path for the chef.

---

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are too "software-heavy." We use light and layering to create a premium feel.

- **The Layering Principle:** Depth is achieved by stacking. A `surface_container_lowest` card sitting on a `surface_container_low` background creates a natural, soft lift.
- **Ambient Shadows:** When a card must float (e.g., a recipe card during scroll), use a highly diffused shadow: `box-shadow: 0 12px 40px rgba(183, 0, 12, 0.08);`. Note the red tint in the shadow—this mimics natural ambient light reflecting off the brand's primary color.
- **The "Ghost Border" Fallback:** If a divider is essential for accessibility, use the `outline_variant` token at **15% opacity**. Anything higher is too aggressive for this system.

---

## 5. Components

### Cards: The Editorial Spread
Cards should never look like "containers." Use `xl` (1.5rem) corner radii.
- **Layout:** Use asymmetric padding—more breathing room at the bottom than the top.
- **Visuals:** Images should bleed to the edges or use a "cutout" style where the sauce bowl overlaps the card boundary.
- **Dividers:** Forbid the use of line dividers within cards. Use `1.5rem` of vertical whitespace to separate the recipe name from the "Quick Stats" (time, spice level).

### Chips: Ingredient Selection
- **Style:** Pill-shaped (`full` roundedness).
- **Default State:** `surface_container_high` background with `on_surface_variant` text.
- **Active State:** `primary_container` background with `on_primary` text.
- **Interaction:** A subtle `scale(0.95)` on press to give a tactile, "squishy" feel.

### Interactive Rating Stars
- **Active:** Use `secondary_container` (#fcd400).
- **Inactive:** Use `surface_container_highest` (#e2e2e2).
- **Design:** Use a custom "sparkle" or soft-edged star icon to maintain the "accessible/social" vibe.

### Buttons: High-Gloss CTAs
- **Primary:** `primary_container` background. `md` (0.75rem) roundedness. Use `label-md` uppercase with 0.05em letter spacing for a premium "button" feel.
- **Tertiary (Ghost):** No background, no border. Use `primary` text weight `600`.

### The "Sauce Ratio" Slider
A custom component for this app. A horizontal track using `surface_container_highest` with a `primary` thumb. As the user slides, the `primary` color fills the track, representing the intensity of the flavor.

---

## 6. Do's and Don'ts

### Do:
- **Do** use whitespace as a functional tool. It creates the "Premium" feel.
- **Do** use `plusJakartaSans` for numbers in recipe ratios—it’s more legible and authoritative.
- **Do** lean into the "Haidilao Red" for moments of celebration (e.g., "Recipe Shared!" or "New Achievement").

### Don't:
- **Don't** use black (#000000) for text. Always use `on_surface` (#1a1c1c) to keep the palette warm.
- **Don't** use standard Material Design "elevated cards" with heavy grey shadows. It breaks the editorial immersion.
- **Don't** crowd the "Ingredient Chip" area. If there are more than 8 ingredients, use a "Show More" fade-out using a gradient from `transparent` to `surface`.

### Accessibility Note:
While we use tonal shifts instead of borders, ensure the contrast ratio between `surface` and `surface_container_highest` meets AA standards for UI elements. Use the `outline` token (#946e69) for focus states to ensure keyboard navigability is never sacrificed for aesthetic.

---

## 7. Screen Reference Notes

The attached visual references define the first-pass mobile UI direction. Treat them as product moodboards, not exact screenshots to copy pixel-for-pixel.

### Login / Auth Entry
- Use a mostly white, quiet screen with a centered brand lockup.
- The brand title should be red, italic, and high-confidence. The Korean subtitle sits below with heavier black text.
- Email and password fields should be large, rounded rectangles with soft red/pink outline treatment and muted brown icon/text color.
- Primary login CTA is a full-width red button with a soft red ambient shadow.
- Secondary text links use warm brown text. Use a small centered dot separator between actions.
- Social login section uses a thin tonal divider and `간편 로그인` label.
- Kakao login uses the official yellow visual treatment, with black/brown icon and text. Keep this visually distinct from the red primary CTA.

### Home Feed
- Top app bar uses a small circular chef/profile image on the left, red centered Korean wordmark, and search icon on the right.
- Search is a large pill surface with a compact red action button on the trailing edge.
- The top content rhythm is editorial: section title, small red `전체보기`, then large recipe cards.
- Weekly popular cards use image-heavy vertical cards with:
  - top image occupying roughly half the card,
  - floating rating badge,
  - bold recipe title,
  - short description,
  - pill ingredient/taste chips,
  - like count and small pink/red add button.
- Latest recipes can sit inside a rounded tonal section band. Use compact horizontal cards with thumbnail, title, short copy, taste indicator, rating/new badge, and engagement count.
- Bottom navigation uses a floating rounded white bar with red active icon/text and muted inactive icons.

### Chef / Public Profile
- Use a simple top bar with back control, centered title, and overflow menu.
- Profile hero is a large rounded tonal card with centered avatar, name, subtitle, stats, and primary follow button.
- Stats should be compact and scan-first: large number, uppercase label.
- Top Recipes are stacked editorial recipe cards with large photos, floating time/rating badges, title, short description, and chips.
- For NuguSauce MVP, this is only a visual reference for future public profile pages. Until a public profile API exists, keep the screen as a placeholder route.

### Recipe Detail
- Use a full-bleed hero image at the top with circular back/favorite controls floating over it.
- The detail body should rise as a rounded top sheet over the hero image.
- Title is large, bold, and multi-line friendly.
- Author, rating, and review count sit in one compact metadata row.
- Ingredient list uses a white rounded card with row separators expressed through tonal spacing/subtle backgrounds rather than strong borders.
- Ingredient rows should emphasize amount/ratio on the trailing side with bold numbers.
- Recommendation chips are small warm-gray pills.
- Chef tip card uses a white elevated surface with red icon/title accent.
- Review cards are soft white rounded surfaces with avatar, name, rating, date, and readable text.
- Floating share/favorite actions can sit near the lower trailing edge, but must not cover review text or primary actions.

### Create Recipe
- Use a clean top bar with the screen title on the left and a red `임시저장` action on the right.
- The first block is a large rounded photo upload area. Use a soft tonal image placeholder, centered camera icon, short primary prompt, and smaller helper text.
- The recipe title field should feel editorial and oversized, with a pale vertical accent line on the leading side. Placeholder text can be large and light gray.
- Description/helper text below the title should be subdued and secondary.
- Taste tags use rounded pill chips. The selected chip is solid red with white text; inactive chips use warm gray surfaces and brown text.
- A custom tag entry chip should use a dashed or low-contrast tactile surface with a leading plus icon.
- Ingredient ratio editing is card-based:
  - each ingredient card uses a white rounded surface and soft shadow,
  - ingredient icon sits in a muted circular chip,
  - ingredient name is bold with category/subtitle below,
  - ratio value is emphasized on the trailing side in red,
  - slider track is pale gray with a red thumb/fill.
- The ingredient section heading stays clean; ingredient additions happen through quick-add controls.
- Quick-add ingredients sit in a horizontal scroll row of compact rounded chips. Use muted disabled-looking chips for unavailable or inactive items.
- The primary submit CTA is a full-width red bottom button with strong vertical padding and soft red ambient shadow.
- The bottom tab bar keeps `등록` active with a red circular plus treatment while other tabs stay muted gray.
- Keep the form spacious. Avoid dense table-form styling; this screen should feel like composing a recipe card.

### Visual Translation Rules For SwiftUI
- Prefer `Color` tokens and semantic component styles over hardcoded one-off colors inside feature views.
- Use large corner radii for editorial recipe surfaces, but keep compact controls ergonomically stable.
- Do not use strong black text. Use warm near-black and brown variants from the palette.
- Use thin borders only for input affordances or accessibility focus. Do not use line dividers as the main layout mechanism.
- Use backend `imageUrl` values when present. If a response has no image URL, use a neutral visual placeholder only as presentation chrome; do not bundle fixture product imagery into the app target.
