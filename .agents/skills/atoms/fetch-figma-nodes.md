# Skill: Fetch Figma Nodes

**Type:** Atom
**Used by:** Pipeline Orchestrator
**Trigger:** Step 4 of pipeline — after branch creation, before handoff build

---

## Purpose
Retrieve structured design data from Figma for every node URL in the spec.
Transforms raw Figma MCP responses into the structured `figmaNodes` format
that developer and QA agents consume.

---

## Inputs
Array of Figma references from the spec:
```json
[
  {
    "url": "https://figma.com/file/ABC123/MyProject?node-id=123:456",
    "nodeId": "123:456"
  }
]
```

---

## Process

### Step 1 — Validate URLs
For each URL:
- Confirm it is a valid Figma URL with a node ID
- Extract the file key and node ID

If a URL is malformed, log it and skip — do not fail the entire pipeline.
Flag the skipped URL in output so the pipeline orchestrator can surface it.

### Step 2 — Fetch via Figma MCP
For each valid node, call the Figma MCP in sequence:

```
mcp.get_metadata(nodeId)     → component name, type, description
mcp.get_variable_defs(nodeId) → design tokens (colors, spacing, typography)
mcp.get_code_connect_map(nodeId) → mapped component library components
mcp.get_screenshot(nodeId)   → visual reference (attach to handoff as URL)
```

If any individual MCP call fails:
- Retry once after a 2-second delay
- If it fails again, log the failure and continue with partial data
- Mark the node with `"partial": true` in the output

### Step 3 — Extract variants and states
From the metadata response, extract:
- Component variants (e.g. primary, secondary, ghost)
- Interactive states (default, hover, focus, disabled, error, loading)
- Responsive breakpoints if defined

Map each variant and state to a structured entry. If the Figma component
uses component properties, extract their names and allowed values.

### Step 4 — Build structured output
Transform the raw MCP responses into the `figmaNodes` schema:

```json
{
  "url": "https://figma.com/file/...",
  "nodeId": "123:456",
  "componentName": "ButtonPrimary",
  "partial": false,
  "tokens": {
    "color-background-primary": "#0052CC",
    "color-text-on-primary": "#FFFFFF",
    "spacing-padding-x": "16px",
    "spacing-padding-y": "8px",
    "border-radius": "4px"
  },
  "variants": [
    { "name": "variant", "values": ["primary", "secondary", "ghost", "danger"] }
  ],
  "states": ["default", "hover", "focus", "disabled", "loading"],
  "codeConnect": "Button",
  "screenshotUrl": "https://...",
  "spec": "Primary action button. Use for the single most important action on a screen. Do not use more than one per viewport."
}
```

---

## Output
```json
{
  "figmaNodes": [ ... ],
  "skipped": ["https://figma.com/... — malformed URL"],
  "partial": ["123:456 — mcp.get_variable_defs timed out"]
}
```

---

## Fallback behaviour
If the Figma MCP is entirely unavailable (connection error on all calls):
- Return `{ "figmaNodes": [], "unavailable": true }`
- The pipeline orchestrator handles this gracefully — it does not block
- Developer and QA agents will see the unavailability flag and request
  Figma context manually if needed

---

## Rules
- Never hallucinate design tokens or component names
- If a token value cannot be confirmed from MCP, omit it — do not guess
- Screenshot URLs are for reference only — do not embed images in handoff.json
- Code connect mappings are hints, not instructions — the developer agent
  applies them with judgement
