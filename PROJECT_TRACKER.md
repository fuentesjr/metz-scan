# Project tracker (superseded)

Work tracking moved to `.trk/` (STATE.md + LOG.md), written through the `trk`
CLI — see the routing rules in `AGENTS.md`. Fresh sessions resume via
`trk status --json`, not this file. `bin/check_tracker_queue` reads
`.trk/STATE.md` `## Next`. Parked issue boundaries for
`bin/render_issue_comment_summary` live in `.trk/LOG.md`.

Recovery of pre-migration chronology:

```sh
git log -- PROJECT_TRACKER.md
git show HEAD~1:PROJECT_TRACKER.md   # last full tracker before migration
```
