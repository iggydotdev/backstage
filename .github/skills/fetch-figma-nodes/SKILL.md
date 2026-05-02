---
name: fetch-figma-nodes
description: >
  Retrieve structured design data from Figma for every node URL in a spec.
  Use this at pipeline Step 4, after branch creation, before building handoff.json.
  Transforms Figma MCP responses into the structured figmaNodes format that
  developer and QA agents consume. Degrades gracefully if Figma is unavailable.
---

# Fetch Figma Nodes

Retrieve design data from Figma and transform it into structured figmaNodes.

## Inputs needed
Array of Figma references from the spec:
- `url` — full Figma URL with node-id parameter
- `nodeId` — e.g. "123:456"

## Step 1 — Validate URLs
For each URL:
- Confirm it is a valid Figma URL with a node ID
- Extract file key and node ID

If a URL is malformed → log it, skip it, flag it in output. Do not fail the pipeline.

## Step 2 — Fetch via Figma MCP
For each valid node, call in sequence:
```
get_metadata(nodeId)       → component name, type, description
get_variable_defs(nodeId)  → design tokens (colors, spacing, typography)
get_code_connect_map(nodeId) → mapped component library components
get_screenshot(nodeId)     → visual reference URL
```

If any individual call fails:
- Retry once after 2 seconds
- If it fails again → continue with partial data, mark node with `"partial": true`

## Step 3 — Extract variants and states
From metadata, extract:
- Component variants (e.g. primary, secondary, ghost)
- Interactive states (default, hover, focus, disabled, error, loading)
- Responsive breakpoints if defined

## Step 4 — Build structured output
```json
{
  "url": "https://figma.com/file/...",
  "nodeId": "123:456",
  "componentName": "ButtonPrimary",
  "partial": false,
  "tokens": {
    "color-background-primary": "#0052CC",
    "spacing-padding-x": "16px",
    "border-radius": "4px"
  },
  "variants": [
    { "name": "variant", "values": ["primary", "secondary", "ghost", "danger"] }
  ],
  "states": ["default", "hover", "focus", "disabled", "loading"],
  "codeConnect": "Button",
  "screenshotUrl": "https://...",
  "spec": "Plain-English description of component intent"
}
```

## Fallback — Figma MCP entirely unavailable
Return `{ "figmaNodes": [], "unavailable": true }`.
Log warning in pipeline.log.ndjson: `{"event": "figma_unavailable", "severity": "warn"}`.
Pipeline continues — developer and QA agents will see the unavailability flag.

## Rules
- Never hallucinate design tokens or component names
- If a token value cannot be confirmed from MCP → omit it, do not guess
- Screenshot URLs are for reference only — do not embed images in handoff.json
- Partial data is better than no data — always return what you have
