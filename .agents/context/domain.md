<!-- SUMMARY -->
Domain: [one-line description of the business domain]
Key integrations: [comma-separated external services]
Notable patterns: [any domain-specific patterns agents should know]
<!-- END SUMMARY -->

# Domain Context

> Produced by the Onboarding Agent. Evolves via PR as the system grows.
> Last updated: [DATE] — context/v[VERSION]

---

## Business domain

[2–3 sentences describing the business domain, the market context, and
any domain-specific knowledge a new developer would need to understand
why things are built the way they are.]

---

## Key integrations

| Service | Purpose | Auth method | Docs |
|---|---|---|---|
| [e.g. Stripe] | Payments | API key | [link] |
| [e.g. SendGrid] | Email | API key | [link] |

---

## Domain-specific patterns

[Any patterns specific to this domain that aren't in the general stack
— e.g. how the industry handles pricing, regulatory constraints,
data ownership rules, etc.]

---

## Glossary additions

> Terms that extend or clarify the system.md domain model with
> implementation-level detail.

**[Term]:** [What it means in this codebase, if different from the generic meaning]

---

## Known gotchas

[Things that have bitten developers before and are worth calling out
explicitly — e.g. "The 'User' model in the DB is called 'Account' in
the UI for historical reasons. Do not rename either."]

- [Gotcha]
- [Gotcha]
