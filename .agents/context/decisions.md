<!-- SUMMARY -->
Active decisions: [count] — see ADR list below for one-liners
Last decision: ADR-[N] — [title]
<!-- END SUMMARY -->

# Architectural Decisions

> Produced by the Architect Agent. Append-only after init.
> Decisions are never deleted — only superseded.
> Last updated: [DATE] — context/v[VERSION]

---

## Active decisions — quick reference

> One line per active ADR. This is what agents read.
> Full rationale is in the ADR blocks below.

| ADR | Decision | Status |
|---|---|---|
| ADR-001 | [One-line summary of the decision] | active |

---

## How to read this

Each decision has:
- **Status**: `active` | `superseded by ADR-NNN` | `proposed`
- **Context**: why this decision was needed
- **Decision**: what was decided
- **Rationale**: why this option over alternatives
- **Consequences**: what becomes easier, what becomes harder

Agents must respect all `active` decisions. If a proposed implementation
conflicts with an active decision, stop and flag it — do not work around
it silently.

---

## ADR-001 — [Short title]

**Status:** active
**Date:** [DATE]

**Context:**
[What situation prompted this decision?]

**Decision:**
[What was decided, stated plainly.]

**Rationale:**
[Why this option? What alternatives were rejected and why?]

**Consequences:**
- ✅ [What becomes easier]
- ⚠️ [Known trade-off]

---

> Add new ADRs below. Never modify existing ones.
> To supersede: add a new ADR and update the old status to
> `superseded by ADR-NNN`. Update the quick reference table too.
