# Context Changelog

Every change to `.agents/context/` is logged here.
Entries are prepended — newest at the top.
This file is updated by the Architect Agent and the Pipeline Orchestrator.

---

## Format

```
## [DATE] — context/vX.Y — [short description]
**Changed by:** architect | onboarding | pipeline-orchestrator (via PR #N)
**Files changed:** system.md | decisions.md | stack.md | domain.md
**Summary:** What changed and why.
**Triggered by:** project init | architect review after N specs | human request
```

---

## Log

## [DATE] — context/v1.0 — Initial context
**Changed by:** architect + onboarding
**Files changed:** system.md, decisions.md, stack.md, domain.md
**Summary:** Architect Agent ran init mode — system vision, domain model, and
initial ADRs established. Onboarding Agent resolved all [SHORTCODE] placeholders
from repository scan + human confirmation.
**Triggered by:** project init

---

> New entries go above this line.
> Never edit or delete existing entries.
> To supersede a decision, add a new ADR in decisions.md and reference it here.
