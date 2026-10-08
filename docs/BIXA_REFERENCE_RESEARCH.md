# Bixa Reference Research — RAD Motion Redesign

**Reference reviewed:** https://bixa.ai/  
**Review date:** 2026-10-08  
**Method:** live browser observation at the public landing page, including hero and two editorial scroll positions. Visual screenshots were captured for internal design analysis only; no Bixa assets or code are included in this repository.

## Scope and provenance

This document records visual and interaction observations from the live Bixa landing page. It does not copy Bixa source code, branding, illustration assets, copy, or proprietary visual assets. The RAD implementation uses the owner-supplied logo, existing verified content, and original Flutter-rendered visual language.

## Directly observed characteristics

The public page uses a near-black base with high-contrast editorial Persian typography. The first view is deliberately asymmetrical: an oversized white brand mark fills the left visual mass while a concise headline and warm focal CTA occupy a restrained right column. A very thin multicolour rule separates hero and subsequent content. The navigation is compact and visually quiet compared with the display type.

The two observed scroll positions establish a repeated editorial rhythm. Sections start with compact indexed metadata such as `01 / LEARN BY BUILDING`, move into large two-line display headlines and narrow body text, then resolve into structured rows or numbered paths. On the second observed position, the page places a dark low-contrast stacked/numbered panel opposite a large heading instead of using a uniform grid of cards. This creates an intentionally asymmetric composition with one active item carrying the visual focus.

Visual depth comes from low-contrast textured/gradient fields, thin borders, large negative space, and small localized warm glows. The page does not spread broad glass blur panels across the interface. It uses compact labels, restrained badges, and explicit ordinal numbers to organize reading.

## Directly observed interaction and motion signals

The header visibly restyles after scrolling. Earlier live computed-style inspection reported a `transform` transition of **0.6s** using `cubic-bezier(0.16, 1, 0.3, 1)`, together with **0.4s** background and border-colour transitions. A visible header CTA brightened under pointer hover; the CTA exposed transform, shadow, and filter transitions around **0.3–0.35s** using the same expressive ease-out curve.

Sequential path articles expose opacity and translate transitions of **0.9s** with **0.13s** stagger increments. Timeline nodes transition border, box-shadow, background, and transform over **0.6s**. The focal brand mark includes a slow `brandFloat` animation with a **7s** ease-in-out cycle. At the observed scroll position, an individual stacked item becomes visibly current instead of animating all content with equal emphasis.

The public page includes a semantic skip link, standard links/buttons, native text input, and native disclosure summaries. The direct review did not establish full mobile gesture behavior or a reference reduced-motion implementation.

## Original RAD interpretation

RAD retains its red primary action colour and owner-supplied logo. It will use an original midnight-navy canvas, teal/cyan navigation and data accents, and red only for brand/action emphasis. The transformation will use Flutter-rendered vector geometry—not Bixa art—through a cinematic path/orbit motif, thin coordinate lines, editorial section indexing, asymmetric panels, and large display typography.

The redesign intentionally differs from the reference in application purpose and behavior. It uses only verified user/application/document data in operational surfaces; it does not invent approval claims, immigration outcomes, destination facts, testimonials, or statistics. Continuous motion remains limited to focal illustration surfaces and actual processing states, with static alternatives for reduced-motion users.

## Implementation boundary

No authentication provider, token handling, database schema, Supabase configuration, production data, Render settings, deployment configuration, or existing authentication-hotfix branch is modified by the visual redesign.
