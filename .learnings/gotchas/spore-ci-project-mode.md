---
title: "Spore CI should target project-mode files explicitly"
category: gotchas
tags: [spore, ci, project-mode, basic-cli]
created: 2026-04-28
context: "basic-cli CI needed to validate a package-backed example with the shipped compiler"
---

## Problem

The current `spore` CLI validates package-backed examples reliably when given the explicit entry file, but bare directory invocations and standalone file assumptions can fail depending on current compiler surface and imports.

## Solution

Use explicit file targets for project-mode checks:

```bash
spore check examples/hello-app/src/main.sp
spore build examples/hello-app/src/main.sp
cd examples/hello-app && spore run src/main.sp
```

## Key points

- Keep CI focused on the canonical package-backed entry file.
- Treat standalone `.sp` examples as separate from project-mode validation.
- Re-run `spore format --check`, `spore check`, and `spore build` against explicit files when compiler behavior is in flux.
