<!-- SUMMARY -->
Stack: [e.g. React 18 + TypeScript + Vite]
Test: [runner] — [command] — [file convention]
Lint: [command] | Type check: [command]
Structure: [e.g. feature-based under src/features/]
Component library: [e.g. shadcn/ui] | State: [e.g. Zustand]
<!-- END SUMMARY -->

# Stack Context

> Produced by the Onboarding Agent. Updated via PR only.
> Last updated: [DATE] — context/v[VERSION]

---

## Core stack

| Concern | Choice | Version |
|---|---|---|
| Framework | [e.g. React] | [18.x] |
| Language | [e.g. TypeScript] | [5.x] |
| Build tool | [e.g. Vite] | [5.x] |
| Package manager | [e.g. pnpm] | [9.x] |

---

## Testing

| Concern | Choice |
|---|---|
| Test runner | [e.g. Vitest] |
| Test command | `[e.g. pnpm test]` |
| Test file convention | [e.g. `*.test.tsx` next to source] |
| Mock library | [e.g. `vi` + `msw` for API mocking] |
| E2E runner | [e.g. Playwright] |
| E2E command | `[e.g. pnpm test:e2e]` |
| A11y command | `[e.g. pnpm test:a11y]` |
| Visual diff command | `[e.g. pnpm test:visual]` |

---

## Quality commands

| Command | What it does |
|---|---|
| `[LINT_COMMAND]` | Linting |
| `[TYPE_CHECK_COMMAND]` | Type checking |
| `[CI_COMMAND]` | Full CI sequence |

---

## Project structure

```
[Describe the folder structure — e.g.]
src/
├── features/       ← feature-based folders
│   └── auth/
│       ├── components/
│       ├── hooks/
│       └── store/
├── components/     ← shared/atomic components
└── lib/            ← utilities and services
```

---

## UI and state

| Concern | Choice | Notes |
|---|---|---|
| Component library | [e.g. shadcn/ui] | |
| Styling | [e.g. Tailwind CSS] | |
| State management | [e.g. Zustand] | |
| Data fetching | [e.g. React Query] | |
| Forms | [e.g. React Hook Form + Zod] | |

---

## Coding standards

- **Style guide:** [e.g. Airbnb ESLint config + project overrides at `.eslintrc`]
- **Naming:** [e.g. PascalCase components, camelCase functions, kebab-case files]
- **Imports:** [e.g. absolute imports via `@/` alias]
- **Standards doc:** [path or "none"]

---

## Key conventions

[Any project-specific patterns agents must follow — e.g.]
- All data fetching goes through the repository layer in `src/lib/repositories/`
- Components do not call APIs directly
- All async state uses React Query — no raw `useEffect` for data fetching
