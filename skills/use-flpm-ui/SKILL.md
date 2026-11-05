---
name: use-flpm-ui
description: >-
  Builds React UI with FLPM UI, Filipe's shadcn registry on Base UI (phosphor
  green, square corners, pixel type). Use when a project's components.json has
  an "@flpm" registry, when setting up FLPM UI in a new or existing React
  project, or when building screens, forms or components for an FLPM Software
  project.
---

# FLPM UI

FLPM UI is a **shadcn registry**: components arrive as source code copied into the project, built on **Base UI** primitives and themed with Tailwind v4 CSS variables. The project owns that code after install.

- Registry: `https://fm1randa.github.io/flpm-ui/r/{name}.json`, index at `.../r/registry.json` (the list of available items).
- Storybook (visual reference for every variant and state): `https://fm1randa.github.io/flpm-ui/`
- Source repo: `fm1randa/flpm-ui`, locally `~/Repositories/apps/flpm-ui`.

## Setup

Run only the steps the project is missing; check `components.json` first.

1. **shadcn on Base UI.** A project without `components.json` gets `npx shadcn@latest init --base base`. A project already on Radix (its `style` is not `base-*`) is a migration: stop and ask before converting.
2. **Namespace.** `components.json` carries `"registries": { "@flpm": "https://fm1randa.github.io/flpm-ui/r/{name}.json" }`.
3. **Theme.** `npx shadcn@latest add @flpm/theme` writes the palette, fonts and CSS variables into the global CSS and installs the font packages.
4. **TooltipProvider** wraps the app root once any tooltip is used.

Setup is done when `npx shadcn@latest add @flpm/button` succeeds and a `<Button>` renders phosphor green with square corners.

## Adding components

Always add with the namespace: `npx shadcn@latest add @flpm/<name>`. A bare `add <name>` pulls the stock shadcn version and overwrites the FLPM one. Each item depends on `@flpm/theme`, so the theme comes along.

Fetch `registry.json` to see what exists. When the screen needs something the registry lacks, compose it from FLPM components and theme classes first; if a new primitive is unavoidable, add the stock shadcn Base UI version and restyle it to the rules below, then tell the user it belongs upstream in `flpm-ui`.

## Base UI, not Radix

Components follow Base UI's API, which differs from the shadcn/Radix examples most code samples show:

- Composition uses the **`render` prop**: `<DialogTrigger render={<Button variant="outline" />}>Open</DialogTrigger>`. The `asChild` prop does not exist.
- `Select` takes an `items` array (`{ label, value }`) on the root so `SelectValue` shows the label of the chosen value.
- State styling uses data attributes: `data-checked`, `data-disabled`, `data-open`.

When in doubt about a component's props, read its file in `src/components/ui/` in the project; that file is the source of truth.

## Visual language

Every rule traces to the FLPM logo: a pixel-art CRT terminal.

- **Square corners everywhere.** The theme maps every `rounded-*` step to `0px`; write `rounded-none` on new elements instead of picking a radius.
- **Type roles.** `font-heading` (Silkscreen) for titles, buttons, labels, badges, short text only: it renders uppercase-like pixels and turns long text into noise. Body text stays in the default `font-sans` (Space Grotesk). `font-mono` (JetBrains Mono) for code.
- **Scale.** display 48/56 bold, h1 32/40 bold, h2 24/32 bold, h3 16/24 regular, all `font-heading`; body 16/24, small 14/20 in `font-sans`; labels 12px `font-heading` with `tracking-wider`.
- **Color pairs.** Use the semantic utilities, always as their pair:

| Role | Classes | Use for |
| --- | --- | --- |
| primary | `bg-primary text-primary-foreground`, hover `bg-primary-hover` | the main action; dark text on phosphor green |
| secondary ("terminal") | `bg-secondary text-secondary-foreground`, hover `bg-secondary-hover` | important non-primary actions, code blocks, hero bands |
| destructive | `bg-destructive text-destructive-foreground` | irreversible actions |
| accent | `bg-accent text-accent-foreground` | hover and selected states on light surfaces |
| muted | `bg-muted`, `text-muted-foreground` | surfaces, secondary text |
| link | `text-link` | links and ghost actions |
| highlight | `bg-highlight` | rare emphasis, one per screen at most |
| disabled | `bg-disabled text-disabled-foreground` | disabled controls |

The raw palette (`green-950` to `green-400`, `lime-300`, `beige-200`) is for illustration and charts; components use the semantic names so dark mode keeps working.
- **Dark mode** is the "terminal" theme under the `.dark` class. Semantic utilities switch automatically; raw palette colors do not.

## Buttons

Button hierarchy per screen: one `default` (primary) for the main action, then `secondary`, `outline` for neutral alternatives (cancel, back), `ghost` inside toolbars and lists, `destructive` only for irreversible actions behind a confirmation `Dialog`. Sizes: `sm` 28px, `default` 32px, `lg` 40px for touch targets on mobile; `icon*` sizes for icon-only buttons, which carry an `aria-label`. Icons come from `lucide-react` and size themselves.

## Done

UI work with FLPM UI is done when every control comes from `@/components/ui` or is built from theme classes, no element has a non-zero radius, every Silkscreen string is short, every colored background uses its semantic pair, and the screen reads correctly in both light and `.dark`.
