# RAD EMIGRATE — CONTENT, VISA & "OTHER TITLES" ARCHITECTURE QA
**Date:** 2026-10-28  
**Scope:** Architectural Integrity of Visa Canonical Pages vs. Other Titles Articles across RAD Visa, DigiVisa, and RAD Mohajer  

---

## 1. ARCHITECTURAL INVARIANT COMPLIANCE

The Employer's exact content architecture specifies:
$$\text{Visa} \longrightarrow \text{Country} \longrightarrow \text{Visa Category} \longrightarrow \text{ONE Continuous Canonical Page} + \text{ONE "دیگر عناوین / Other Titles" Section}$$

### Concrete Architecture Guarantees:
1. **Canonical Visa Pages**:
   - Built exclusively from substantive, authoritatively vetted material from `radvisa.com` and `digivisa.ir`.
   - Combined into a single, cohesive, rich-text continuous page with headings, tables, conditions, and exceptions preserved.
   - Zero synthetic summaries; zero truncated requirements.
   - Verified 148 canonical page inventory items.

2. **Other Titles ("دیگر عناوین")**:
   - Independent legacy articles from `radmohajer.com` remain separate standalone articles.
   - They appear under the "دیگر عناوین" section of the relevant country/category card.
   - Retain complete original text, source citations, and URL provenance.
   - Verified 944 active independent locales in the draft delivery package.

3. **Human Review Safeguard**:
   - The 264 incomplete/unavailable sources and 434 human-review queue items are flagged with `editorial_approval: false`.
   - They are NOT auto-published into production.
