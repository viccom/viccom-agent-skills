---
name: type-styles-and-radius
description: Derive and enforce a closed matrix of named text styles (Heading, Title, Body, Button, Caption) from a project's own type scale, and compute nested corner radii. Use when deciding which size and weight a table cell, card title, nav item or button label uses; when auditing font-size or font-weight usage for drift; or when a shape sits inside a card or panel and its corner radius must look concentric. Not for choosing fonts, palettes, layout, motion or visual direction.
license: MIT. Adapts elayadesign/ai-design-skills (landing-page-design B1-B3).
---

# Type styles and nested radius

Two precise rules that a type scale does not give you on its own. Both assume a
project that already has, or is about to define, a type scale and a radius
scale. Neither rule chooses a look.

**Not this skill.** Font selection, palette, layout, motion and page structure
belong to `frontend-design`, `hallmark` or `design-taste-frontend`. Colour-token
architecture belongs to `design-system`. This skill only decides which existing
step a piece of text or a nested corner uses.

## 1. Named text styles

### The failure this prevents

A scale such as `12 / 14 / 16 / 20 / 24 / 28` says which sizes exist. It does
not say which size and weight a table cell, a card title, a nav item or a
button label uses. Left to judgement, the same role drifts. One measured
console ended up with 11 distinct sizes, 6 improvised values, and three
different page-title sizes across three pages.

### The rule

Every piece of text resolves to exactly one named style. A style is a pair: one
scale step plus one weight. Never a loose size, never a loose weight.

Five groups, numbered from strongest to lightest:

| Group | Use for |
|---|---|
| `Heading N` | Page and section headings, largest first. `Heading 1` is the page title. |
| `Title N` | Card titles, list-item titles, labels that lead a block, nav items. |
| `Body N` | Running text. Within one size, `1` is the heaviest and the last number is regular. |
| `Button-*` | Text inside buttons only. |
| `Caption N` | Metadata, helper text, badges, timestamps, fine print. |

Rules:

- One `Heading 1` per page. Content headings start at `Heading 2`, because the
  page title already owns `h1`.
- Two elements with the same role use the same style. If they look alike but
  need different styles, they are different roles: name them.
- A new need gets the next number in its group, built from an existing scale
  step. Never an off-scale size, never a new group name.
- Implement each style once as a kebab-case class or token (`heading-2`,
  `body-4`, `button-md`, `caption-1`) and apply the class. Do not repeat
  size-plus-weight utilities on every element.
- Tracking and line-height may only be adjusted inside the value the matched
  step already provides. Do not pair a snapped size with an unrelated custom
  line-height.

### Deriving the matrix from an existing scale

1. Read the scale from the project's tokens: CSS custom properties,
   `tailwind.config.*`, or a `tokens.css`. Do not invent steps.
2. If a needed size is off the scale, **snap down** to the nearest step below
   and take that step's paired line-height. Never snap up: a paragraph meant to
   be small must not grow.
3. Use only weights the family actually ships (commonly 400, 500, 600). Cap at
   semibold unless the brand supplies a bold role.
4. Write the matrix into the project's token file or design doc, so the next
   agent reads it instead of re-deciding.

A worked derivation on the scale `12 / 14 / 16 / 20 / 24 / 28`:

| Style | Step | Weight |
|---|---|---|
| `heading-1` | 28 | 600 |
| `heading-2` | 24 | 600 |
| `heading-3` | 20 | 600 |
| `title-1` | 20 | 500 |
| `title-2` | 16 | 500 |
| `body-1` | 16 | 400 |
| `body-2` | 14 | 400 |
| `button-md` | 14 | 600 |
| `caption-1` | 12 | 500 |
| `caption-2` | 12 | 400 |

Copy the method, not these numbers. A project on a different scale gets a
different matrix. For a project that has adopted Tailwind's default scale, a
ready-made 26-style matrix is in
[`references/tailwind-default-matrix.md`](references/tailwind-default-matrix.md).

### Audit

```bash
# Raw sizes are the smell. Every hit is either a token definition or a bug.
rg -n 'font-size:\s*[0-9]|text-\[[0-9]' --glob '!**/node_modules/**'
```

Every hit is one of three things: a token definition, an intentional
`em`-based cascade (the markdown body scaling `h2`/`h3`/`code` against a reading
size is legitimate), or a bug. A clean project has zero raw sizes outside its
token file except the deliberate `em` cascade. `design-system`'s
`validate-tokens.cjs` is the complementary check: it flags hardcoded px and hex
values across a directory.

## 2. Nested radius

Applies to **concentric surfaces**: a shape whose edges run parallel to its
parent's — a card inside a card, a panel inside a card, an image or media block
inside a padded container. It does **not** apply to controls. Buttons, inputs,
badges and chips take their radius from the control system, not from the
container they happen to sit in; forcing them to the formula turns every button
inside a 12px-padded card into a square.

When a concentric surface sits inside another shape and the gap between them is
under 32px:

```
inner radius = outer radius - gap
```

Apply it only when the result is **greater than 2**. Otherwise leave the inner
shape square or unchanged: a 1-2px radius reads as a rendering artefact, not a
decision. If the gap is 32px or more, leave the inner radius as the surface
system specifies; the corners are far enough apart that they no longer read as
concentric.

| Outer | Gap | `outer - gap` | Result |
|---|---|---|---|
| 16 | 8 | 8 | use 8 |
| 12 | 4 | 8 | use 8 |
| 24 | 16 | 8 | use 8 |
| 8 | 8 | 0 | leave square |
| 6 | 4 | 2 | not > 2, leave unchanged |

Why: concentric corners read as one object. Equal radii on nested shapes read
as two objects that happen to overlap.

Checklist for every concentric nested surface:

- [ ] Read the parent's radius and the padding between parent and child.
- [ ] If the gap is under 32, compute `outer - gap`.
- [ ] If the result is greater than 2, snap it to the nearest radius token that
      does **not exceed** the computed value.
- [ ] If the result is 2 or less, leave the child square.

## Checklist

- [ ] Every text element maps to a named style; no loose size-plus-weight pairs
- [ ] One `Heading 1` per page; content headings start at `Heading 2`
- [ ] No raw `font-size` outside the token file
- [ ] New styles follow the group numbering and use an existing scale step
- [ ] Every concentric nested surface follows `outer - gap`, applied only when
      the result is greater than 2
- [ ] Computed radii snap to the project's radius tokens, never to an arbitrary
      value

## Attribution

The named-style matrix, the snap-down rule and the nested-radius formula are
adapted from [`elayadesign/ai-design-skills`](https://github.com/elayadesign/ai-design-skills)
(`landing-page-design` sections B1-B3, MIT). The group names and the 26-style
Tailwind matrix are theirs. The derivation method for non-Tailwind scales, the
one-`h1` rule and the radius token-snapping are adapted for projects that do not
use Tailwind's defaults.
