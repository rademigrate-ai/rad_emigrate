# 04 — USER CHANGE HIGHLIGHT SYSTEM

## 1. User Trust & Factual Transparency

Immigration applicants rely on RAD Emigrate for critical legal decisions involving significant financial and personal commitments. A subtle regulatory change (e.g. minimum language score increasing from CLB 7 to CLB 8, or proof of funds rising by \$2,000) can result in visa refusal if an applicant acts on outdated data.

The **User Change Highlight System** guarantees complete factual transparency by surfacing verified updates directly to end-users without overwhelming the reading experience.

---

## 2. Component Design (`ArticleChangeHighlightsBanner`)

Implemented in `lib/features/visa/presentation/widgets/article_change_highlights_banner.dart` and mounted prominently in `canonical_pathway_page.dart`:

### A. Compact State (Default View)
- Positioned immediately beneath the pathway header and above the narrative sections.
- Shows:
  - Calendar update indicator: *«تاریخ انطباق: ۲۰۲۶/۱۰/۲۴»*.
  - Primary Government Authority: *«Immigration, Refugees and Citizenship Canada (canada.ca)»*.
  - Expand/collapse toggle arrow.

### B. Expanded Audit Drawer
When tapped, the banner smoothly expands to disclose:
1. **Official Legal Citations:**
   - Authority name and domain.
   - Direct statutory hyperlink to the official government gazette or ministerial instruction.
2. **Verification State Seal:**
   - Displays a green shield badge with the explicit guarantee:
     *«این مقاله تحت کنترل سردبیری انسانی بازبینی و تصویب شده است؛ هوش مصنوعی دسترسی انتشار خودکار ندارد.»*
     *(This article has been reviewed and approved under human editorial control; artificial intelligence does not possess automated publication authority.)*

---

## 3. Strict Anti-Leak Boundaries

A core security invariant verified by automated regression tests:
1. **Public Read-Only Projection:** The public application queries `published_visa_articles` or `get_visa_article`, which filters strictly on:
   ```sql
   WHERE editorial_state = 'published' AND is_active = true
   ```
2. **Draft & Proposal Isolation:**
   - Unapproved research proposals, worker candidate drafts, and reviewer rejection notes are stored in private administrative schemas.
   - Public JWTs cannot read from `research_proposals` or `article_revisions` where `editorial_state != 'published'`.
   - The highlight banner extracts dates and sources solely from the immutable published revision payload, ensuring that zero pre-publication speculation is ever visible to public users.
