# Design System Document: The Editorial Kitchen

This design system is a bespoke framework crafted for a high-end, appetizing food planning experience. It moves beyond standard mobile templates to create a digital environment that feels as fresh as a farmers' market and as organized as a Michelin-star kitchen.

---

## 1. Overview & Creative North Star: "The Culinary Curator"

The Creative North Star for this system is **The Culinary Curator**. We are not building a utility; we are building an assistant that feels like a premium lifestyle magazine. 

To achieve this, the system breaks the "standard app" look by embracing **intentional asymmetry** and **tonal depth**. Rather than rigid grids, we use overlapping elements—such as high-quality food photography breaking the bounds of its container—and dramatic typography scales to create a sense of movement and "soul." The goal is a layout that breathes, using whitespace as a functional ingredient rather than just a gap between components.

---

## 2. Colors & Surface Philosophy

The palette is a celebration of freshness: vibrant greens (`primary`) represent growth and health, while warm oranges (`secondary`) evoke appetite and sun-ripened produce.

### The "No-Line" Rule
**Standard 1px borders are strictly prohibited.** To define sections, designers must use background color shifts. For example, a recipe card (`surface-container-lowest`) should sit on a `surface-container-low` section, which itself sits on the global `surface`. Boundaries are felt through tone, not drawn with lines.

### Surface Hierarchy & Nesting
Treat the UI as a series of stacked, organic layers. Use the `surface-container` tiers to create depth:
*   **Base Layer:** `surface` (#f4fbf6)
*   **Secondary Sectioning:** `surface-container-low` (#eff5f0)
*   **Interactive Cards:** `surface-container-lowest` (#ffffff)
*   **Elevated Modals:** `surface-bright` (#f4fbf6)

### The Glass & Gradient Rule
To prevent a "flat" feel, main CTAs and Hero sections should utilize a **Signature Texture**. Use a subtle linear gradient (Top-Left to Bottom-Right) transitioning from `primary` (#026b1e) to `primary_container` (#2b8535). For floating navigation or top bars, apply **Glassmorphism**: use `surface` at 80% opacity with a `20px` backdrop blur to allow food imagery to bleed through softly.

---

## 3. Typography: Editorial Clarity

We use **Plus Jakarta Sans** for its modern, geometric-yet-warm personality.

*   **Display (lg/md/sm):** Used for "Daily Inspiration" or "Hero Headlines." These should be set with tight letter-spacing (-0.02rem) to feel like a premium cookbook.
*   **Headline (lg/md/sm):** Reserved for category titles (e.g., "Breakfast," "Meal Prep").
*   **Title (lg/md/sm):** Used for recipe names and card headers. `title-lg` should be bold to provide immediate visual hierarchy.
*   **Body (lg/md/sm):** High-readability weights for ingredients and instructions. Use `body-lg` for method steps to ensure they are legible from a distance in a kitchen.
*   **Label (md/sm):** Used for nutritional data and timestamps.

**Typography as Identity:** Use `display-md` in `on_surface_variant` (#3f493d) to create "quiet" but large headers that frame the content without competing with the food imagery.

---

## 4. Elevation & Depth: Tonal Layering

We avoid traditional drop shadows in favor of **Ambient Light** and **Tonal Layering**.

*   **The Layering Principle:** Depth is achieved by "stacking." A recipe card (`surface-container-lowest`) placed on a `surface-container-low` background creates a natural lift.
*   **Ambient Shadows:** If an element must float (e.g., a Floating Action Button), use a highly diffused shadow: `0px 12px 32px` with 6% opacity of `on_surface` (#161d1a). This mimics soft, overhead kitchen lighting.
*   **The "Ghost Border" Fallback:** If accessibility requires a stroke, use `outline_variant` at **15% opacity**. Never use a 100% opaque border.
*   **Roundedness:** Adhere to the `xl` (3rem) scale for large hero imagery and `lg` (2rem) for primary cards to maintain a friendly, approachable hand-feel.

---

## 5. Components

### Buttons
*   **Primary:** Gradient of `primary` to `primary_container`. Shape: `full` (pill). Text: `on_primary`.
*   **Secondary:** `secondary_fixed` background with `on_secondary_fixed` text. Use for "Add to Cart" or "Save."
*   **Tertiary:** Ghost style. No background, `primary` text.

### Cards & Lists (The "No-Divider" Rule)
*   **Cards:** Use `rounded-lg` (2rem). Imagery should always be top-aligned or bleed off one edge. **Never use divider lines.**
*   **List Separation:** Use `spacing-6` (1.5rem) of vertical whitespace or a subtle shift to `surface-container-low` to separate list items.

### Custom Component: The "Freshness Gauge"
A custom chip using `tertiary_container` (#5b7a78) with `on_tertiary_container` (#f3fffd) text to indicate how long ingredients stay fresh, utilizing the `sm` (0.5rem) roundedness scale.

### Input Fields
Soft backgrounds (`surface-container-highest`) instead of outlined boxes. When focused, the background should transition to `surface-container-lowest` with a 2px `primary` ghost border (20% opacity).

---

## 6. Do’s and Don’ts

### Do:
*   **Do** use high-quality, "macro" food photography. Let the colors of the food dictate the mood.
*   **Do** use asymmetrical margins. For example, a left-hand margin of `spacing-8` and a right-hand margin of `spacing-4` for a dynamic editorial feel.
*   **Do** lean into the `primary_fixed` (#9bf899) color for success states—it feels "ripe" and positive.

### Don't:
*   **Don't** use black (#000000). Always use `on_surface` (#161d1a) for text to maintain a soft, organic feel.
*   **Don't** use standard "Material" shadows. If it looks like a default shadow, it’s too heavy.
*   **Don't** cram content. If a screen feels busy, increase the spacing from `spacing-4` to `spacing-8`.
*   **Don't** use hard 90-degree corners. Everything in the kitchen (and this app) should feel "sanded" and safe.