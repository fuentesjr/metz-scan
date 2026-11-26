---
name: Release checklist
about: Track a metz-scan and rubocop-metz release
title: "Release vX.Y.Z"
labels: release
assignees: ""
---

`RELEASE_CHECKLIST.md` is the canonical release checklist.

Generate a clickable release tracking issue from `RELEASE_CHECKLIST.md`:

```bash
bin/create_release_issue
```

Or preview the generated issue locally without GitHub access:

```bash
bin/create_release_issue --dry-run
```

If you are opening a release issue manually instead, follow `RELEASE_CHECKLIST.md` directly.
