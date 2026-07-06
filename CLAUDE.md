# Claude Code project notes

Orient from `PROJECT_TRACKER.md` first. Run `bin/check_ci_parity` before any
push. Tracker standing rules govern slice discipline.

## Delegating to Codex (openai-codex plugin)

Work is delegated via the `codex:codex-rescue` agent + `codex-companion.mjs`.
Upstream bug to defend against: openai/codex-plugin-cc#432 (root-cause class
in #222) — a foreground companion run wrapped in a harness background shell
gets reaped when the subagent exits, killing the companion before it writes a
terminal status. The job record wedges at `running` forever even though the
Codex turn usually completes server-side and the work lands on disk.

Protocol:

- Dispatch the rescue subagent in the FOREGROUND (`run_in_background: false`)
  as a thin forwarder: one companion `task` call, return the task ID, no
  waiting or polling inside the subagent. Never satisfy "background" with a
  harness background shell around a foreground companion run; ask for the
  companion's own `--background` mode explicitly as belt-and-suspenders.
- Poll `status <task-id>` from the main session with a bounded loop (the
  #31/#32-scale tasks ran ~34m; poll every 5-8m, cap around 60-90m).
- If status seems stuck at `running`, check three signals before concluding
  anything: (1) job log mtime (path is in status output; live runs append
  regularly), (2) recorded worker pid liveness (`kill -0 <pid>`), (3) the job
  JSON under the plugin's `state/<workspace>/jobs/<task-id>.json` — a missing
  `request` key means a foreground run and exactly the #432 wedge (healthy
  background jobs always store `request`).
- Recovery for a wedged record: verify the deliverable in the working tree
  directly (run tests, inspect the diff) — never trust status output alone —
  then clear the stale record with `codex-companion.mjs cancel <task-id>`.
  The Codex session ID in status output stays valid for later `--resume`.
- Independent review is mandatory regardless: rerun the focused tests and
  read the full diff before updating the tracker or committing.
- Tell Codex to use agenticons for helper investigations and the required
  reviewer, and to leave committing/pushing to the orchestrating session.
