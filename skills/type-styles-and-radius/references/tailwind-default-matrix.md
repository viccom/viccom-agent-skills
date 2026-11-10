# Tailwind-default text-style matrix

Use this only if the project has actually adopted Tailwind's default type
scale. If the project defines its own scale (for example `12 / 14 / 16 / 20 /
24 / 28`), derive the matrix from that scale with the method in `SKILL.md`
instead. Importing these numbers into a project with a different scale defeats
the point of the rule.

## Scale steps

| Class | Size | Line height |
|---|---|---|
| `text-xs` | 12px | 16px |
| `text-sm` | 14px | 20px |
| `text-base` | 16px | 24px |
| `text-lg` | 18px | 28px |
| `text-xl` | 20px | 28px |
| `text-2xl` | 24px | 32px |
| `text-3xl` | 30px | 36px |
| `text-4xl` | 36px | 40px |
| `text-5xl` | 48px | 1 |
| `text-6xl` | 60px | 1 |
| `text-7xl` | 72px | 1 |
| `text-8xl` | 96px | 1 |
| `text-9xl` | 128px | 1 |

If a size falls between steps, snap to the closest step below and take that
step's paired line height.

## Styles

| Style | Scale step | Size / line height | Weight |
|---|---|---|---|
| Heading 1 | `text-6xl` | 60 / 60 | Semibold |
| Heading 2 | `text-5xl` | 48 / 48 | Semibold |
| Heading 3 | `text-4xl` | 36 / 40 | Semibold |
| Heading 4 | `text-3xl` | 30 / 36 | Semibold |
| Heading 5 | `text-2xl` | 24 / 32 | Semibold |
| Heading 6 | `text-xl` | 20 / 28 | Semibold |
| Title 1 | `text-xl` | 20 / 28 | Medium |
| Title 2 | `text-lg` | 18 / 28 | Medium |
| Title 3 | `text-base` | 16 / 24 | Medium |
| Title 4 | `text-sm` | 14 / 20 | Medium |
| Title 5 | `text-xs` | 12 / 16 | Medium |
| Body 1 | `text-base` | 16 / 24 | Semibold |
| Body 2 | `text-base` | 16 / 24 | Medium |
| Body 3 | `text-base` | 16 / 24 | Regular |
| Body 4 | `text-sm` | 14 / 20 | Semibold |
| Body 5 | `text-sm` | 14 / 20 | Medium |
| Body 6 | `text-sm` | 14 / 20 | Regular |
| Button-lg | `text-lg` | 18 / 28 | Semibold |
| Button-md | `text-base` | 16 / 24 | Semibold |
| Button-sm | `text-sm` | 14 / 20 | Semibold |
| Button-Xsm | `text-xs` | 12 / 16 | Semibold |
| Caption 1 | `text-sm` | 14 / 20 | Medium |
| Caption 2 | `text-sm` | 14 / 20 | Regular |
| Caption 3 | `text-xs` | 12 / 16 | Semibold |
| Caption 4 | `text-xs` | 12 / 16 | Medium |
| Caption 5 | `text-xs` | 12 / 16 | Regular |

## Notes

- **`Body 1` is not a title.** It is the heaviest running-text style. Use
  `Title N` for anything that leads a block.
- **One `Heading 1` per page.** In a markdown renderer, demote the document's
  own top-level heading to `Heading 2` when the page chrome already renders an
  `h1`.
- **Do not invent styles.** A new need gets the next number in its group (for
  example `Body 7`), built from an existing scale step.
- **Tailwind v4 projects** may define the theme in CSS via `@theme` rather than
  `tailwind.config.js`. Read the resolved values from the CSS before deriving a
  matrix; do not assume the defaults.

Source: `elayadesign/ai-design-skills`, `landing-page-design` section B1 (MIT).
