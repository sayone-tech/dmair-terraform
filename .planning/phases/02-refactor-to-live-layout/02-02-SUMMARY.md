---
phase: 02-refactor-to-live-layout
plan: 02
status: complete
---

# Plan 02-02 Summary — Reserve live/dmair/staging/ slot for dmair-backend

## Status

**complete.** Pure documentation; no AWS interaction required by anyone.

## File created

- `live/dmair/staging/README.md` — placeholder describing the staging-environment slot, the conventions stacks under it follow, and the cross-repo contract with `dmair-backend` (DNS `api-staging.flydmair.com` + OIDC role scoped to `live/dmair/staging/*`).

Commit: `7de5aaa` `docs(REFACTOR-02): reserve live/dmair/staging/ slot for dmair-backend`.

Satisfies **REFACTOR-02 success criterion 4** (`live/dmair/staging/` exists with at least a placeholder README; reserved for dmair-backend slot).
