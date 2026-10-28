# 09 — FLUTTER UI/UX IMPLEMENTATION

## 1. Visual Hierarchy & Design System Integration

All components created and enhanced in Plan 4 strictly adhere to RAD Emigrate's design system tokens (`AppColors`, `AppRadii`, `PremiumTokens`), maintaining full RTL Persian layout support, accessibility landmarks, and ergonomic interaction patterns.

---

## 2. Component Specifications

### A. `AdminSourceDiffPage` (`lib/features/admin/presentation/pages/admin_source_diff_page.dart`)
- **Header Card:** Displays authority name, verification state, official domain, and canonical evidence URL.
- **Segmented View Selector:**
  - `تغییرات بخش‌ها` (Section Changes): Structured visual comparison.
  - `شواهد و مدارک` (Evidence & Proofs): Dedicated cards detailing publisher, URL, and Persian-quoted excerpt.
  - `کد خام JSON` (Raw JSON): High-contrast code view with monospace typography for technical audit.
- **Action Zone:**
  - Visual disclaimer banner highlighting that approval does not auto-publish.
  - Editorial notes text input.
  - Symmetrically weighted Outlined (`رد تغییرات`) and Filled (`تأیید و ایجاد پیش‌نویس`) action buttons.

### B. `AdminSourceMonitorPage` (`lib/features/admin/presentation/pages/admin_source_monitor_page.dart`)
- **Dual-Tab Interface:**
  - Tab 0: Change Proposals with status chips (`در انتظار بررسی`, `تأیید پیش‌نویس`, `رد شد`).
  - Tab 1: Official Authorities directory with domain list and verification status badge (`تأییدشده رسمی`, `موقت`, `منقضی‌شده`).
- **Interactive Triggers:**
  - "واکشی تغییرات منبع": Dispatches on-demand crawl refresh with in-place pending indicator (`RadPending()`).
  - "شناسایی مرجع جدید": Modal dialog capturing country code, competence topic, and profession.

### C. `AdminCmsCanonicalEditorPage` (`lib/features/admin/presentation/pages/admin_cms_canonical_editor_page.dart`)
- **Ergonomic Action Bar:**
  - Save Draft and Submit for Review buttons are positioned immediately below the Title and Summary fields, preventing overflow on small viewports.
- **Section Block Preview:**
  - Renders section cards showing heading, anchor (`#anchor`), and block counters.
- **Revision History Modal:**
  - Draggable bottom sheet with historical revision sequence, author, timestamps, and rollback action.

### D. `ArticleChangeHighlightsBanner` (`lib/features/visa/presentation/widgets/article_change_highlights_banner.dart`)
- **Subtle Surface Canvas:**
  - Crisp white container with 0.3 alpha teal border and soft shadow.
- **Micro-Interactions:**
  - Smooth expansion toggle revealing primary government citations and human editorial seal.
  - Zero generic spinners: uses `RadPending` and theme-compliant motion primitives.
