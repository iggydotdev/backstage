# Security

This document defines the minimum security posture required to run
the agentic pipeline safely. It is a process recommendation, not an
implementation — the execution environment is the tool's responsibility.

---

## Core principle

**Agents should have the minimum access required to do their job.**

Agents write code and commit to branches. They should not be able to
merge, delete branches, modify protected branches, or access secrets
beyond what the current spec requires. If an agent is compromised or
behaves unexpectedly, the blast radius should be limited to a single
feature branch.

---

## Git access model

### What agents need
- Read access to `develop` and all feature branches
- Write access to their own feature branch only
- Ability to open PRs — but not merge them
- No access to `main`

### What agents must never have
- Force-push permissions on any branch
- Merge permissions on `develop` or `main`
- Ability to delete branches (archive-spec moves files, not branches)
- Access to branch protection rules or repo settings

### Recommended setup
Create a dedicated git identity for pipeline agent runs:

```bash
git config user.name  "pipeline-agent[bot]"
git config user.email "pipeline-agent@your-org.com"
```

Use a scoped token (GitHub fine-grained PAT or equivalent) with:
- **Repository permissions:** Contents (read/write), Pull requests (write)
- **No organisation permissions**
- **Expiry:** 90 days maximum — rotate on schedule

Never use a personal access token with broad permissions.
Never commit the token to any file, including `handoff.json`.

---

## Branch protection

Set these rules on `develop` and `main` before running the pipeline:

| Rule | develop | main |
|---|---|---|
| Require PR before merging | ✅ | ✅ |
| Require human approval (min 1) | ✅ | ✅ |
| Block force pushes | ✅ | ✅ |
| Restrict who can push directly | Admins only | Admins only |
| Require status checks to pass | ✅ | ✅ |

The pipeline orchestrator opens PRs. A human approves them.
No agent ever merges directly.

---

## What a misbehaving agent can do

If an agent produces bad output or behaves unexpectedly, here is what
it can and cannot affect under the model above:

| Action | Possible? | Mitigation |
|---|---|---|
| Commit bad code to feature branch | ✅ Yes | Human review before merge |
| Merge bad code to develop | ❌ No | Branch protection + required approval |
| Overwrite another spec's branch | ❌ No | Scoped per-run token, named branches |
| Access secrets in other branches | ❌ No | Branch-scoped access only |
| Delete branches | ❌ No | No delete permission granted |
| Push to main | ❌ No | Branch protection |
| Expose secrets from handoff.json | ⚠️ Risk | See Secrets section below |

The human review step (draft PR → approval) is the primary safety gate.
No agent output reaches `develop` without a human seeing it first.

---

## Secrets

**Never put secrets in `handoff.json` or `agentNotes`.**

`handoff.json` is committed to the feature branch and visible in git
history. It is not the right place for API keys, tokens, credentials,
or any sensitive value.

If an agent needs a secret to do its job (e.g. the Figma MCP needs an
API token), that secret must be:
- Stored in the execution environment's secret store (GitHub Actions
  secrets, local `.env` not committed, tool-specific vault)
- Injected at runtime by the tool, not by the pipeline process
- Never logged to `pipeline.log.ndjson`

If `agentNotes` accidentally contains a sensitive value, rotate the
affected credential immediately and rewrite the git history to remove it.

---

## Execution environment

The pipeline is tool-agnostic — it runs inside whatever AI tool the
team uses. Regardless of tool, the following apply:

**Recommended:** Run agents in an isolated environment where possible.
- GitHub Actions: agents run in ephemeral VMs with scoped tokens
- Local: run in a Docker container or devcontainer with limited host access
- Cloud IDEs: verify the tool's sandboxing model before use

**Minimum:** Even without isolation, the git access model above limits
what a misbehaving agent can affect.

**Not recommended:** Running agents with admin credentials, on a machine
with access to production systems, or with a token that has org-wide
permissions.

---

## MCP server trust

The pipeline uses MCPs (Figma, optionally Jira/Azure DevOps).
Each MCP is an external service call. Apply the same trust model
you would to any third-party API:

- Use read-only MCP scopes where possible (Figma Dev Mode is read-only)
- Do not grant MCP servers write access unless explicitly required
- Review what data each MCP call sends to the external service
- For sensitive codebases, verify the MCP provider's data handling policy

---

## Audit trail

The pipeline maintains its own audit trail in two places:

- `pipeline.log.ndjson` — every event, every agent, every transition
- `handoff.json > audit` — per-spec append-only log

These are the primary record for reviewing what an agent did and when.
Preserve them. Do not truncate `pipeline.log.ndjson` while a spec
is in flight.

---

## Incident response

If an agent produces output that should not be merged:

1. Close the draft PR without merging
2. Delete the feature branch: `git push origin --delete feature/SPEC-NNN-slug`
3. Move the spec back to `.specs/active/` if it was modified
4. Investigate `pipeline.log.ndjson` for what happened
5. Re-trigger the pipeline orchestrator for a fresh run

If a secret was exposed in a commit:
1. Rotate the credential immediately — assume it is compromised
2. Use `git filter-repo` or BFG to rewrite history
3. Force-push the rewritten history (requires temporary admin access)
4. Notify affected parties per your organisation's incident policy

---

## What this pipeline does not cover

- Code scanning or SAST (use your existing CI tooling)
- Dependency vulnerability scanning (use Dependabot or equivalent)
- Runtime security of the application being built
- Compliance attestations (SOC 2, ISO 27001, etc.)
- AI model safety or output filtering beyond what the tool provides

These are outside the scope of the pipeline process. Use your existing
security tooling for these concerns alongside the pipeline.
