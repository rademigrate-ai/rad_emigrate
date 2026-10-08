# Bixa Reference Research — RAD Motion Redesign

**Reference reviewed:** https://bixa.ai/
**Review date:** 2026-10-08
**Method:** live browser observation at the public landing page; visual screenshots were captured for internal analysis only and are not committed to this repository.

## Scope and provenance

This document records visual and interaction observations from the live Bixa landing page. It does not copy Bixa source code, branding, illustration assets, copy, or proprietary visual assets. The RAD implementation uses an original design system, its owner-supplied logo, and the existing product’s verified data and content.

## Observed design characteristics

- A **very dark, near-black surface** establishes a cinematic presentation while preserving high-contrast Persian typography.
- The hero is deliberately sparse: oversized brand mark at one side, a compact navigation bar, strong two-line editorial heading, restrained supporting copy, and two clear CTA styles.
- Warm multicolour gradients are confined to focal accents (brand / CTA), rather than spread across every surface.
- Content is sequenced as a long-form narrative with a small uppercase-style section index, large headline, short explanation, then a structured interaction or card group.
- A thin multi-colour divider and low-contrast background texture create visual depth without obscuring content.
- Cards and rows use thin borders, muted fills, generous whitespace, and a single active/highlighted state.
- The layout makes individual ideas easy to scan through numbered steps, short headings, factual callouts, and compact badges.

## Observed motion and interaction patterns

- The sticky header was visibly restyled after scrolling. Live computed styles reported a `transform` transition of **0.6s** using `cubic-bezier(0.16, 1, 0.3, 1)`, plus **0.4s** background and border-colour transitions.
- Primary CTA elements expose transform, shadow, and filter transitions around **0.3–0.35s** with the same expressive ease-out curve. A live pointer hover over the visible header CTA produced the observed brighter highlighted CTA state.
- Sequential path articles use opacity and translate transitions of **0.9s**, staggered by **0.13s** increments.
- Timeline nodes transition border, box-shadow, background, and transform over **0.6s**.
- The visual brand mark includes a slow, continuous `brandFloat` animation with a **7s** ease-in-out cycle.
- A scrolling section visibly switched an item to a highlighted “current” state rather than animating all content at once.
- The page presents a semantic skip link, standard links/buttons, native text input, and native `summary` disclosure controls.

## Visual depth techniques

- Low-contrast layered backgrounds and fine border lines provide depth instead of broad blur panels.
- Small, localised glow/gradient accents give important actions and timeline states hierarchy.
- Motion is concentrated around entrances, selected states, and navigation changes; it is not used as a permanent full-page spectacle.
- The focal hero brand has a slow ambient movement, while reading surfaces remain visually stable.

## Typography and composition

- Right-to-left Persian composition uses compact navigation, asymmetrical hero balance, large display type, and deliberate line breaks.
- Section metadata, numbers, and product labels establish rhythm before headings.
- Body copy is narrower and lower contrast than headings, preserving hierarchy and reading comfort.
- The page alternates editorial sections with structured, utilitarian content blocks.

## Responsive and accessibility observations

- The live page uses semantic anchors, buttons, input controls, and disclosure summaries.
- The reviewed live viewport presented a persistent header and a readable stacked long-form layout.
- The reference’s rich motion is not a requirement for RAD: the product must prioritize keyboard use, touch input, form safety, and system reduced-motion preferences.
- The review did not establish all mobile-specific gesture behaviour or an explicit reduced-motion stylesheet; RAD will not claim parity where it was not directly observed.

## Original RAD reinterpretation

RAD will use an original **midnight-navy / teal-cyan** motion language, retaining the existing red as the authoritative brand/action colour:

1. **Motion tokens:** centralized, reduced-motion-aware timing and curves for entrances, feedback, hover, progress, content reveal, and modal transitions.
2. **Layered product surfaces:** subtle navy/teal ambient gradients only in hero, splash, and AI surfaces; operational data screens remain neutral and high-contrast.
3. **Interactive cards:** keyboard-focusable, touch-safe elevation/scale feedback and a controlled border highlight, applied through shared Flutter widgets.
4. **Progress and status:** data-driven transitions only; no synthetic approvals, statistics, uploads, bookings, or AI-processing states.
5. **Loading experience:** semantic skeletons and restrained spinners instead of blocking decorative effects.
6. **RTL/LTR discipline:** use directional geometry/alignments and direction-aware entrances rather than fixed left/right motion.

## Implementation boundary

No authentication provider, token handling, database schema, Supabase configuration, production data, Render settings, deployment configuration, or existing authentication-hotfix branch is modified by this work.
