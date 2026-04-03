# Design System: Taste Standard
<!-- Glen Design Gold Standard Example -->

---

## Configuration — Set Your Style

| Dial | Level | Description |
|------|-------|-------------|
| **Creativity** | `9` | 1=울트라 미니멀 ↔ 10=에디토리얼, 볼드 |
| **Density** | `5` | 1=갤러리 에어리 ↔ 10=콕핏 덴스 |
| **Variance** | `8` | 1=대칭 그리드 ↔ 10=아트시 카오틱 |
| **Motion Intent** | `6` | 1=정적 ↔ 10=시네마틱 |

---

## 1. Visual Theme & Atmosphere

A restrained, gallery-airy interface with confident asymmetric layouts and fluid spring-physics motion. The atmosphere is clinical yet warm — like a well-lit architecture studio where every element earns its place through function. Density is balanced (Level 5), variance runs high (Level 8) to prevent symmetrical boredom, and motion is fluid but never theatrical (Level 6). The overall impression: expensive, intentional, alive.

**Key Characteristics:**
- Expansive whitespace with intentional negative space
- Asymmetric layouts preventing grid monotony
- Photography-first with minimal UI interference
- Spring-physics motion feel (documented for code phase)
- Single accent color anchoring all interactions
- Skeleton shimmer loaders matching exact layout dimensions

## 2. Color Palette & Roles

### Background Surfaces
- **Canvas White** (#F9FAFB) — Primary background. Warm-neutral, never clinical blue-white
- **Pure Surface** (#FFFFFF) — Card and container fill. With whisper shadow for elevation

### Text & Content
- **Charcoal Ink** (#18181B) — Primary text. Zinc-950 depth — never pure black
- **Steel Secondary** (#71717A) — Body text, descriptions, metadata. Zinc-500 warmth
- **Muted Slate** (#94A3B8) — Tertiary text, timestamps, disabled states

### Brand & Accent (Pick ONE per project)
- **Emerald Signal** (#10B981) — For growth, success, positive data dashboards
- **Electric Blue** (#3B82F6) — For productivity, SaaS, developer tools
- **Deep Rose** (#E11D48) — For creative, editorial, fashion-adjacent projects
- **Amber Warmth** (#F59E0B) — For community, social, warm-toned products

### Border & Divider
- **Whisper Border** (rgba(226,232,240,0.5)) — Card borders, structural 1px lines
- **Diffused Shadow** (rgba(0,0,0,0.05)) — Card elevation. Wide-spreading, 40px blur

### Status Colors
- **Success** (#10B981) — Confirmation, positive indicators
- **Error** (#EF4444) — Warnings, critical alerts
- **Info** (#64748B) — Neutral system messages

## 3. Typography Rules

### Font Family
- **Primary**: `Geist`, fallback: `SF Pro Display, -apple-system, system-ui, sans-serif`
- **Monospace**: `Geist Mono`, fallback: `JetBrains Mono, ui-monospace, monospace`

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|------|--------|-------------|----------------|-------|
| Display XL | Geist | clamp(2.25rem, 5vw, 3.75rem) | 800 | 1.1 | -0.025em | Hero headlines, maximum impact |
| Display | Geist | 2.25rem | 700 | 1.1 | -0.025em | Section headlines |
| Heading 1 | Geist | 1.75rem | 700 | 1.2 | -0.02em | Major section titles |
| Heading 2 | Geist | 1.5rem | 600 | 1.25 | -0.015em | Sub-section headings |
| Body Large | Geist | 1.125rem | 400 | 1.65 | normal | Introduction text |
| Body | Geist | 1rem | 400 | 1.65 | normal | Standard reading text |
| Caption | Geist | 0.875rem | 400 | 1.5 | normal | Metadata, timestamps |
| Label | Geist | 0.75rem | 500 | 1.4 | 0.01em | Button text, small labels |
| Code | Geist Mono | 0.875rem | 400 | 1.6 | normal | Code blocks |

### Principles
- Weight-driven hierarchy: 800 (display) → 700 (heading) → 400 (body) → 500 (label)
- Track-tight at display sizes (-0.025em), normal at body
- Body max-width 65ch for comfortable reading
- Density > 7: all numbers switch to Monospace

## 4. Component Stylings

### Buttons
**Primary** — Accent fill, white text, rounded-lg, py-2.5 px-6. Hover: subtle darken. Active: translateY(-1px) or scale(0.98)
**Secondary/Ghost** — Transparent bg, accent text, 1px accent border. Hover: whisper accent tint
**Icon Button** — 40x40px, rounded-full, ghost style

### Cards & Containers
- Background: Pure Surface (#FFFFFF)
- Border: 1px Whisper Border (rgba(226,232,240,0.5))
- Radius: 2.5rem (generously rounded)
- Shadow: 0 20px 40px -15px rgba(0,0,0,0.05)
- Padding: 2rem-2.5rem internal
- Hover: subtle shadow intensify
- Density > 7: replace with border-top dividers

### Inputs & Forms
- Label above input, error below in Deep Rose
- Border: 1px Whisper Border
- Focus: 2px accent ring with offset
- Radius: matching buttons (rounded-lg)
- No floating labels

### Badges & Pills
- Background: accent at 10% opacity
- Text: accent color
- Radius: rounded-full
- Font: 0.75rem weight 500

### Navigation
- Sleek, sticky header
- Clean horizontal with generous spacing
- Desktop: no hamburger
- Mobile: slide-in or full-screen overlay
- Active: accent underline or background tint

## 5. Layout Principles

### Spacing System
- Base unit: 8px (0.5rem)
- Scale: 4, 8, 12, 16, 24, 32, 48, 64, 96px

### Grid & Container
- CSS Grid for all structural layouts
- Max content width: 1400px, centered
- Horizontal padding: 1rem (mobile), 2rem (tablet), 4rem (desktop)

### Whitespace Philosophy
- Section margins: 5-8rem between major sections
- Darkness/emptiness as intentional design element
- Content density inversely proportional to creativity dial

### Border Radius Scale
- Micro (2px): Inline badges, subtle tags
- Standard (8px): Buttons, inputs
- Card (1.25rem): Cards, dropdowns
- Large (2.5rem): Featured panels
- Pill (9999px): Pills, status tags
- Circle (50%): Avatars, icon buttons

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat | No shadow, Canvas White bg | Page background |
| Subtle | rgba(0,0,0,0.03) 0 1px 2px | Inline elements, toolbar |
| Surface | Whisper border + diffused shadow | Cards, containers |
| Elevated | rgba(0,0,0,0.08) 0 8px 24px | Dropdowns, popovers |
| Dialog | rgba(0,0,0,0.12) 0 16px 48px + overlay | Modals, command palettes |

**Shadow Philosophy**: Shadows are always diffused and wide-spreading, never harsh or tight. Shadow color stays neutral — no brand-tinted shadows unless intentional (like Stripe's blue shadows). Elevation communicates hierarchy: flat for background, subtle for interactive, elevated for floating.

## 7. Do's and Don'ts

### Do
- Use single accent color consistently across all interactive elements
- Apply weight-driven typography hierarchy (800 → 700 → 400)
- Keep border-radius generous (2.5rem for cards)
- Use skeleton shimmer loaders matching exact layout dimensions
- Test at 375px, 768px, 1024px, 1440px viewports
- Use `min-h-[100dvh]` for full-height sections
- Name colors semantically: "Charcoal Ink" not "dark gray"

### Don't
- Use pure black (#000000) — always Off-Black or Zinc-950
- Use Inter font in premium/creative contexts
- Use emoji as UI icons — SVG only (Lucide, Heroicons)
- Use 3-column equal card layouts for features
- Use centered Hero when variance > 4
- Use circular loading spinners — skeleton shimmer only
- Use AI copywriting clichés ("Elevate", "Seamless", "Unleash")
- Fabricate statistics or metrics not provided by user

## 8. Responsive Behavior

### Breakpoints
| Name | Width | Key Changes |
|------|-------|-------------|
| Mobile | < 768px | Single column, full-width buttons, stacked cards |
| Tablet | 768-1024px | 2-column grids, moderate padding |
| Desktop | 1024-1440px | Full layout, asymmetric grids |
| Large | > 1440px | Centered content, generous margins |

### Touch Targets
- All interactive elements minimum 44px tap target
- Full-width buttons on mobile
- Generous spacing between clickable items

### Collapsing Strategy
- Hero: Display XL → Display via clamp(), asymmetry maintained
- Navigation: horizontal → slide-in mobile menu
- Bento grids: asymmetric → stacked single column
- Section spacing: 5-8rem → clamp(3rem, 8vw, 6rem)
- Inline image typography: images stack below headline on mobile

## 9. Agent Prompt Guide

### Quick Color Reference
- Primary CTA: [Chosen Accent] (e.g., #10B981)
- Background: Canvas White (#F9FAFB)
- Card Surface: Pure White (#FFFFFF)
- Heading text: Charcoal Ink (#18181B)
- Body text: Steel Secondary (#71717A)
- Muted text: Muted Slate (#94A3B8)
- Border: Whisper (rgba(226,232,240,0.5))
- Shadow: Diffused (rgba(0,0,0,0.05))

### Example Component Prompts
- "Create a hero section on #F9FAFB background. Headline at clamp(2.25rem,5vw,3.75rem) Geist weight 800, line-height 1.1, letter-spacing -0.025em, color #18181B. Subtitle at 1.125rem weight 400, line-height 1.65, color #71717A. Single accent CTA button with generous rounded corners."
- "Design a card: #FFFFFF background, 1px rgba(226,232,240,0.5) border, 2.5rem radius, diffused shadow 0 20px 40px -15px rgba(0,0,0,0.05). Title at 1.25rem Geist weight 600, color #18181B. Body at 1rem weight 400, color #71717A."
- "Build a sticky navigation on #F9FAFB. Geist 0.875rem weight 500 for links, #71717A text. Accent CTA right-aligned with rounded-lg."

### Iteration Guide
1. Set font-family to Geist (display/body) and Geist Mono (code)
2. Weight hierarchy: 800 display, 700 heading, 400 body, 500 label
3. Single accent color — everything else is grayscale Zinc
4. Shadows always diffused and wide-spreading
5. Cards use generous 2.5rem radius with whisper borders
6. Test all viewports before delivery (375px → 1440px)
7. Skeleton shimmer for loading, never circular spinners
