<!-- SUMMARY -->
System: [one-line product description]
Users: [comma-separated user types]
Core concepts: [comma-separated domain concept names]
Key constraint: [single most important non-negotiable constraint]
Current epic: [active epic ID and title]
<!-- END SUMMARY -->

# System Context

> Produced by the Architect Agent. Updated via PR only.
> Last updated: [DATE] — context/v[VERSION]

---

## Product

**One-line description:**
[What the system does and for whom]

**Problem being solved:**
[What exists today instead, and why this is better]

**Success in 6 months looks like:**
[Measurable or observable outcomes]

---

## Users

| User type | Description | Primary goals |
|---|---|---|
| [User type] | [Who they are] | [What they want to achieve] |

---

## Domain model

Core concepts and their relationships. Every term here is the canonical
name — all agents and specs must use these exact terms.

### Concepts

**[ConceptName]**
[Plain-English description. What it is, what it contains, how it behaves.]
Relationships: [related concept], [related concept]

**[ConceptName]**
[Plain-English description.]
Relationships: [related concept]

> Add one block per domain concept. Aim for 5–15 concepts.
> Mark anything not yet fully understood as [TBD].

### Relationships diagram (optional)
```
[ConceptA] ──owns──> [ConceptB]
[ConceptA] ──belongs to──> [ConceptC]
```

---

## System boundaries

### This system owns
- [Capability or data domain]

### Delegated to external services
| Concern | Service | Notes |
|---|---|---|
| Authentication | [e.g. Auth0] | |
| Payments | [e.g. Stripe] | |

### Explicitly out of scope (for now)
- [Feature or capability]

---

## Key qualities

Ordered by priority. Agents make tradeoffs in this order.

1. [e.g. Accessibility — WCAG AA is non-negotiable]
2. [e.g. Performance — core flows must feel instant]
3. [e.g. Simplicity — prefer fewer moving parts]

---

## Constraints

- [Non-negotiable constraint]
- [Non-negotiable constraint]

---

## Open questions

- [ ] [Question that must be resolved before related specs go to active/]
