# Final approved slim navigation

Baseline: `83eaa513c3778149b17f5411528724e943427302`, on the existing PR 54 branch. The [owner-approved board](approved-design.png) was inspected at original resolution before this patch. The original `rad_flying_bird_1024.png` SHA-256 is `5922e4874cdcaaddfd4ec90e133d764733a7dfc7039b134ca66b8a59c0c22a06` and must remain unchanged.

## Measured differences before implementation

| Element | Existing Flutter implementation | Approved board / scoped correction |
|---|---|---|
| Glass body | 83 px within 96 px reserved height | 48 px slim continuous capsule, with a separate raised-bird/touch area |
| Margins | 12 px sides, 8 px bottom outside safe area | 16 px sides, retain bottom safe-area clearance |
| Bird | 76 px frame, oversized relative to 24 px icons | Smaller unframed original bird, slightly raised, preserving aspect ratio and motion |
| Selection | 46 px radial background around the icon | Soft red highlight behind the complete icon/label destination |
| Labels | Fixed 18 px line box even at larger text scales | Five permanent labels; grow line boxes and capsule for accessible large text |

The existing pearl/smoky gradients, blur and thin edge highlight already follow the board's glass direction. No other screens or loading states need redesign for this task. The board's illustrated bird does not override the immutable original artwork. Persian follows the app's existing RTL destination order, English LTR; the AI remains centered.

Before evidence is reused: [FA light](../nav-loading-patch/after/nav-fa-light.png), [FA dark](../nav-loading-patch/after/nav-fa-dark.png), [EN light](../nav-loading-patch/after/nav-en-light.png), [EN dark](../nav-loading-patch/after/nav-en-dark.png).

Capture budget: exactly four final actual Flutter screenshots, one per locale/theme combination, in one pass. No new before captures, matrices or image generation.

## Visually inspected result

| View | Final actual Flutter rendering |
|---|---|
| Persian / light | [Screenshot](after/nav-fa-light.png) |
| Persian / dark | [Screenshot](after/nav-fa-dark.png) |
| English / light | [Screenshot](after/nav-en-light.png) |
| English / dark | [Screenshot](after/nav-en-dark.png) |

All four screenshots were captured once at 390 x 844 with zero browser errors, then inspected at original resolution against the approved board. The capsule is continuous, its default glass body measures 48 logical px with a 24 px radius, and all five labels remain visible. The total 60 px destination area includes headroom for the raised bird; 16 px side margins and 8 px bottom clearance sit outside device-safe insets. Surrounding icons remain 24 px. The bird uses a 44 px presentation frame (approximately 34 px visible original artwork in the fixed idle pose), with no orb/rim. The existing animation canvas is uniformly scaled rather than squeezing the artwork or changing anatomy/motion.

The selected destination has a 48 x 44 px soft red highlight behind both icon and label. Light glass retains the translucent pearl gradient; dark glass uses a restrained smoky tint, a thin highlight and reduced shadow. Large system text deliberately increases the capsule height and permits up to three label lines at 200% rather than clipping or shrinking the requested text. Regression checks use the actual Vazirmatn font and verify EN/FA wrapping at 320 px, minimum 48 px touch targets, device-safe clearance, tab order, keyboard activation, More access and the original unrecolored asset.

[Capture manifest](after/manifest.json) identifies the exact application tree and source hashes. [Preservation proof](preservation.json) records the five unchanged bird PNG hashes and unchanged motion/callback sections. The navigation renders the verified 1024 px master; other bird consumers retain their existing asset and behavior. Only four production Dart files and two navigation tests changed in this patch.

Final-HEAD formatting, analysis, full Flutter tests, production web release, Android arm64 debug build and GitHub CI are merge gates. Their final results, commit identity and merge outcome are recorded in [PR 54](https://github.com/rademigrate-ai/rad_emigrate/pull/54).

## Remaining limits

The supplied original bird takes precedence over the mockup's illustrated pose and glow. Persian retains the application's RTL order (Home on the right); English remains LTR, with AI centered in both. Screenshots use actual Flutter widgets with synthetic repositories and Reduced Motion, without phone bezels or simulated system chrome. Device-safe spacing is covered by widget tests with a 34 px bottom inset. Physical-device rendering, iOS builds and native keyboard testing were not performed. This is a focused visual comparison, not a pixel similarity score.

No unrelated screen redesign, loading changes, business/auth/backend contract changes, Supabase changes, migrations, original artwork edits, deployment or destructive cleanup. The second local clone is untouched. No further screenshots or cosmetic iteration are planned for this task.
