// Professionalism sprint: Tier 1 + light Tier 2 public-surface polish.
// In-repo edits are git-revertible. GitHub metadata/PR actions are explicit.
// Does not commit or push — orchestrator or user lands the result.

let meta = #{
    name: "professionalism-sprint",
    description: "Public-surface polish for metz-scan: badges, contributing path, templates, root hygiene, GitHub topics",
    when_to_use: "When the repo works well but still reads like a private workshop on GitHub",
    phases: [
        #{ title: "Inventory", detail: "confirm gaps against the sprint checklist" },
        #{ title: "Implement", detail: "in-repo docs, templates, root relocation" },
        #{ title: "GitHub surface", detail: "topics, wiki/projects, Dependabot PR" },
        #{ title: "Verify", detail: "focused docs tests and tree hygiene" },
        #{ title: "Review", detail: "read-only review of the working tree" },
    ],
};

let inventory_schema = #{
    "type": "object",
    "required": ["ready", "blockers", "notes"],
    "properties": #{
        "ready": #{ "type": "boolean" },
        "blockers": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 8 },
        "notes": #{ "type": "string" },
    },
};

let implement_schema = #{
    "type": "object",
    "required": ["ok", "changed_paths", "skipped", "summary"],
    "properties": #{
        "ok": #{ "type": "boolean" },
        "changed_paths": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 40 },
        "skipped": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
        "summary": #{ "type": "string" },
    },
};

let github_schema = #{
    "type": "object",
    "required": ["ok", "actions", "summary"],
    "properties": #{
        "ok": #{ "type": "boolean" },
        "actions": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 20 },
        "summary": #{ "type": "string" },
    },
};

let verify_schema = #{
    "type": "object",
    "required": ["ok", "commands", "failures", "summary"],
    "properties": #{
        "ok": #{ "type": "boolean" },
        "commands": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 20 },
        "failures": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
        "summary": #{ "type": "string" },
    },
};

let review_schema = #{
    "type": "object",
    "required": ["ok", "blockers", "concerns", "nits", "summary"],
    "properties": #{
        "ok": #{ "type": "boolean" },
        "blockers": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
        "concerns": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
        "nits": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
        "summary": #{ "type": "string" },
    },
};

// --- Phase: Inventory -------------------------------------------------------
phase("Inventory");
log("Confirming public-surface gaps before edits");

let inv_prompt = "";
inv_prompt += "You are inventorying the metz-scan repo at the workspace root for a professionalism sprint.\n";
inv_prompt += "Use read-only tools only (list_dir, read_file, grep, run_terminal_command for git/gh status).\n";
inv_prompt += "Check and report on these expected gaps (do not fix anything):\n";
inv_prompt += "1. GitHub topics empty? CI/version badges missing from README top?\n";
inv_prompt += "2. README Contributing section leads with trk/AGENTS instead of human clone/bundle/rake?\n";
inv_prompt += "3. Missing CONTRIBUTING.md, SECURITY.md, bug/feature issue templates?\n";
inv_prompt += "4. Root working papers present: implementation-notes.md, debt.md, metz_scan_design.md, PROJECT_TRACKER.md stub?\n";
inv_prompt += "5. Wiki/Projects enabled? Open Dependabot PR #38?\n";
inv_prompt += "6. Any docs-freshness tests that pin README Contributing wording?\n";
inv_prompt += "Set ready=true if the sprint can proceed without unresolved blockers.\n";
inv_prompt += "List real blockers only (e.g. dirty tree that would mix work, missing gh auth). Notes: one short paragraph.\n";

let inv = agent(inv_prompt, #{
    label: "inventory",
    capability_mode: "read-only",
    output_schema: inventory_schema,
});

if inv == () || !inv.success || inv.output == () {
    pause("infra", "Inventory agent failed — resume after checking tools, or stop the run.");
}
if inv.output.ready != true {
    let blockers_text = json_encode(inv.output.blockers);
    pause("verification", "Inventory reported not ready. Blockers: " + blockers_text);
}

// --- Phase: Implement (in-repo) ---------------------------------------------
phase("Implement");
log("Applying in-repo docs, templates, and root hygiene");

let impl_prompt = "";
impl_prompt += "Implement the metz-scan professionalism sprint IN-REPO changes only.\n";
impl_prompt += "Do NOT commit, push, tag, publish, or open PRs. Do NOT close GitHub issues.\n";
impl_prompt += "Do NOT change Ruby production code, analyzers, thresholds, or gem versions.\n";
impl_prompt += "Do NOT edit .trk/STATE.md goals or invent new product work.\n\n";
impl_prompt += "Workspace: current git repo root (metz-scan).\n\n";
impl_prompt += "## Required deliverables\n\n";
impl_prompt += "### 1. README.md polish\n";
impl_prompt += "- Add a short badge line near the top (after the H1 title is fine):\n";
impl_prompt += "  - CI status: GitHub Actions badge for the main CI workflow on branch main\n";
impl_prompt += "  - Gem version: https://badge.fury.io/rb/metz-scan.svg linking to rubygems.org/gems/metz-scan\n";
impl_prompt += "  - License badge optional (MIT)\n";
impl_prompt += "- Rewrite the **Contributing / Development** section so a cold human contributor sees first:\n";
impl_prompt += "  clone, Ruby >= 3.3, bundler 4.0.8, bundle install, bundle exec rake, bundle exec rubocop,\n";
impl_prompt += "  and a short pointer that issues are welcome.\n";
impl_prompt += "- Move agent/tracker orientation (trk status, AGENTS.md, CLAUDE.md, DDR note) under a\n";
impl_prompt += "  clearly labeled **Maintainer / agent notes** subsection at the end of Contributing,\n";
impl_prompt += "  not the first paragraph.\n";
impl_prompt += "- Keep existing verified content that docs tests pin, especially mentions of\n";
impl_prompt += "  bin/check_ci_parity, 'clean clone preserved at', and 'next action:'.\n";
impl_prompt += "- Keep the link to skills/metz-scan/SKILL.md if present elsewhere.\n";
impl_prompt += "- Link to CONTRIBUTING.md once it exists.\n";
impl_prompt += "- Do not invent product claims you cannot verify.\n\n";
impl_prompt += "### 2. CONTRIBUTING.md (new, short)\n";
impl_prompt += "- Human-first: how to report bugs, propose features, set up the repo, run tests.\n";
impl_prompt += "- Mention exit code 1 from scan means findings, not crash.\n";
impl_prompt += "- One short paragraph that maintainer/agent coordination lives in AGENTS.md / CLAUDE.md / .trk — optional for external contributors.\n";
impl_prompt += "- Link SECURITY.md for vulnerability reports.\n";
impl_prompt += "- Keep it under ~80 lines. Prose quality: frame why, no hollow structure.\n\n";
impl_prompt += "### 3. SECURITY.md (new, short)\n";
impl_prompt += "- One paragraph: report security issues privately via GitHub Security Advisories\n";
impl_prompt += "  (https://github.com/fuentesjr/metz-scan/security/advisories/new) or by opening a\n";
impl_prompt += "  private report if available; do not file public issues for vulns.\n";
impl_prompt += "- Scope: the metz-scan / rubocop-metz gems and this repository.\n";
impl_prompt += "- Note that design-pressure findings are not security findings.\n\n";
impl_prompt += "### 4. Issue templates under .github/ISSUE_TEMPLATE/\n";
impl_prompt += "- Keep existing release_checklist.md as-is.\n";
impl_prompt += "- Add bug_report.md (YAML frontmatter: name, about, title, labels bug).\n";
impl_prompt += "- Add feature_request.md (labels enhancement).\n";
impl_prompt += "- Templates: observable problem / repro / environment for bugs; problem / proposal for features.\n";
impl_prompt += "- Keep each template concise.\n\n";
impl_prompt += "### 5. Root working-paper relocation\n";
impl_prompt += "- Create docs/maintainers/ if needed.\n";
impl_prompt += "- Move (git mv preferred when tracked):\n";
impl_prompt += "  - implementation-notes.md → docs/maintainers/implementation-notes.md\n";
impl_prompt += "  - debt.md → docs/maintainers/debt.md\n";
impl_prompt += "  - metz_scan_design.md → docs/maintainers/metz_scan_design.md\n";
impl_prompt += "- For PROJECT_TRACKER.md: either delete after confirming it is only a superseded stub,\n";
impl_prompt += "  or move to docs/maintainers/PROJECT_TRACKER.md with the same stub content plus a note.\n";
impl_prompt += "  Prefer delete if nothing but a pointer to .trk remains and no test requires the file path.\n";
impl_prompt += "  (test/metz_scan/metz_scan_skill_test.rb only forbids PROJECT_TRACKER.md inside the consumer skill.)\n";
impl_prompt += "- Update in-repo references that would 404 for humans:\n";
impl_prompt += "  - CLAUDE.md pointer to implementation-notes.md\n";
impl_prompt += "  - docs/application-operations.md link to metz_scan_design.md\n";
impl_prompt += "  - Any README links if present\n";
impl_prompt += "- Historical dogfooding notes that mention PROJECT_TRACKER.md can stay (archive).\n";
impl_prompt += "- Do NOT move AGENTS.md, CLAUDE.md, RELEASE_CHECKLIST.md, LICENSE, or .trk/.\n";
impl_prompt += "- Add docs/maintainers/README.md (5–15 lines) listing what lives there and that\n";
impl_prompt += "  .trk is the live tracker.\n\n";
impl_prompt += "### 6. Optional light polish\n";
impl_prompt += "- If gemspec lacks documentation_uri, set it to the README on GitHub for both gems.\n";
impl_prompt += "  Only if safe and consistent with existing metadata style.\n\n";
impl_prompt += "## Quality bar\n";
impl_prompt += "- Concise, human-readable docs; no AI-slop section padding.\n";
impl_prompt += "- Prefer edit over rewrite of README install/quick-start (already good).\n";
impl_prompt += "- After edits: git status --short and ensure no accidental secrets.\n";
impl_prompt += "- If a docs test would fail from a required string removal, keep that string.\n\n";
impl_prompt += "Return ok=true only if the required deliverables 1–5 are done. List changed_paths and any skipped items with reasons.\n";

let impl = agent(impl_prompt, #{
    label: "implement-docs",
    capability_mode: "all",
    agent_type: "coding-worker",
    output_schema: implement_schema,
});

if impl == () || !impl.success || impl.output == () {
    pause("infra", "Implement agent failed. Inspect the working tree, then resume or stop.");
}
if impl.output.ok != true {
    pause("verification", "Implement reported ok=false: " + impl.output.summary);
}

// --- Phase: GitHub surface --------------------------------------------------
phase("GitHub surface");
log("Topics, wiki/projects, Dependabot PR");

let gh_prompt = "";
gh_prompt += "Apply GitHub *surface* changes for fuentesjr/metz-scan. Do not commit local code.\n";
gh_prompt += "You have admin API access via gh. Be idempotent: re-running should be safe.\n\n";
gh_prompt += "### Required\n";
gh_prompt += "1. Set repository topics (replace empty set) to a sensible set including at least:\n";
gh_prompt += "   ruby, rubocop, rails, static-analysis, code-quality, cli, linter\n";
gh_prompt += "   Also include sandi-metz if GitHub accepts the slug (topics are lowercase).\n";
gh_prompt += "   Use: gh api -X PUT repos/fuentesjr/metz-scan/topics -f names[]=...  (or the documented REST form).\n";
gh_prompt += "   Note: topics API often needs Accept: application/vnd.github.mercy-preview+json — use whatever gh currently requires.\n";
gh_prompt += "2. Disable wiki and projects if enabled and unused:\n";
gh_prompt += "   gh api -X PATCH repos/fuentesjr/metz-scan -f has_wiki=false -f has_projects=false\n";
gh_prompt += "3. Optionally set homepage to https://rubygems.org/gems/metz-scan if currently empty.\n\n";
gh_prompt += "### Dependabot PR #38\n";
gh_prompt += "- Inspect PR #38 (actions/checkout bump).\n";
gh_prompt += "- If CI is green and the change is the expected Dependabot bump only, merge it with gh pr merge\n";
gh_prompt += "  (squash or merge per repo default). If CI red or conflicted, leave open and report in actions.\n";
gh_prompt += "- Do not force-merge failing CI.\n\n";
gh_prompt += "### Do not\n";
gh_prompt += "- Change branch protection\n";
gh_prompt += "- Create issues or comments on closed issues\n";
gh_prompt += "- Publish gems or create releases\n\n";
gh_prompt += "Return ok=true if topics are set and wiki/projects disabled (or already disabled). Dependabot merge is best-effort.\n";
gh_prompt += "List each action taken as a short string.\n";

let gh = agent(gh_prompt, #{
    label: "github-surface",
    capability_mode: "all",
    output_schema: github_schema,
});

if gh == () || !gh.success || gh.output == () {
    pause("infra", "GitHub surface agent failed. Local edits may still be good; resume after checking gh.");
}
if gh.output.ok != true {
    log("GitHub surface incomplete: " + gh.output.summary);
}

// --- Phase: Verify ----------------------------------------------------------
phase("Verify");
log("Running focused verification on docs and related tests");

let ver_prompt = "";
ver_prompt += "Verify the professionalism-sprint working tree in this metz-scan repo.\n";
ver_prompt += "Do not commit or push.\n\n";
ver_prompt += "Run and record:\n";
ver_prompt += "1. git status --short and git diff --stat\n";
ver_prompt += "2. Confirm required new files exist: CONTRIBUTING.md, SECURITY.md,\n";
ver_prompt += "   .github/ISSUE_TEMPLATE/bug_report.md, .github/ISSUE_TEMPLATE/feature_request.md,\n";
ver_prompt += "   docs/maintainers/README.md\n";
ver_prompt += "3. Confirm root no longer has implementation-notes.md, debt.md, metz_scan_design.md\n";
ver_prompt += "   (they should live under docs/maintainers/)\n";
ver_prompt += "4. Confirm README has a badge line and Contributing leads with human setup, not trk first\n";
ver_prompt += "5. Focused tests (use project load path from CLAUDE.md):\n";
ver_prompt += "   bundle exec ruby -Ilib -Itest -Irubocop-metz/lib -Irubocop-metz/test \\\n";
ver_prompt += "     test/metz_scan/readme_workflow_docs_test.rb \\\n";
ver_prompt += "     test/metz_scan/metz_scan_skill_test.rb \\\n";
ver_prompt += "     test/metz_scan/agent_workspace_docs_test.rb \\\n";
ver_prompt += "     test/metz_scan/readme_project_analyzer_status_test.rb 2>/dev/null || true\n";
ver_prompt += "   Also run any other README freshness tests under test/metz_scan/ that match readme_*\n";
ver_prompt += "6. If gemspecs changed, ensure they still parse: ruby -e \"load 'metz-scan.gemspec'\" etc.\n";
ver_prompt += "7. Spot-check broken links you introduced (relative paths).\n\n";
ver_prompt += "Set ok=true only if required files exist, root papers moved, and focused tests you ran passed.\n";
ver_prompt += "List commands run and failures with output snippets.\n";

let ver = agent(ver_prompt, #{
    label: "verify",
    capability_mode: "all",
    output_schema: verify_schema,
});

if ver == () || !ver.success || ver.output == () {
    pause("infra", "Verify agent failed.");
}
if ver.output.ok != true {
    // One fix pass, then re-verify is expensive; pause for human/orchestrator.
    pause("verification", "Verify failed: " + ver.output.summary + " failures=" + json_encode(ver.output.failures));
}

// --- Phase: Review ----------------------------------------------------------
phase("Review");
log("Read-only review of the sprint diff");

let rev_prompt = "";
rev_prompt += "Review the uncommitted professionalism-sprint changes in this metz-scan repo.\n";
rev_prompt += "Read-only: git diff, git status, read files. Do not edit.\n\n";
rev_prompt += "Checklist:\n";
rev_prompt += "1. Public docs speak to humans first; agent process is secondary.\n";
rev_prompt += "2. No broken relative links for moved files.\n";
rev_prompt += "3. No accidental secrets, no unrelated refactors, no Ruby behavior changes unless gemspec metadata only.\n";
rev_prompt += "4. Issue templates are usable and not padded.\n";
rev_prompt += "5. SECURITY.md is correct and doesn't claim a private email that doesn't exist.\n";
rev_prompt += "6. README badges use correct repo path fuentesjr/metz-scan and workflow file if referenced.\n";
rev_prompt += "7. Nothing under rubocop-metz/lib references metz_scan incorrectly.\n\n";
rev_prompt += "Classify: blockers (must fix), concerns (should fix), nits.\n";
rev_prompt += "ok=true only if no blockers.\n";

let rev = agent(rev_prompt, #{
    label: "review",
    capability_mode: "read-only",
    agent_type: "reviewer",
    output_schema: review_schema,
});

if rev == () || !rev.success || rev.output == () {
    pause("infra", "Review agent failed.");
}

// Optional fix pass if review has blockers
if rev.output.ok != true {
    log("Review found blockers; attempting one fix pass");
    let fix_prompt = "";
    fix_prompt += "Fix ONLY the review blockers from the professionalism sprint. Do not commit.\n";
    fix_prompt += "Blockers JSON: " + json_encode(rev.output.blockers) + "\n";
    fix_prompt += "Concerns (fix if cheap): " + json_encode(rev.output.concerns) + "\n";
    fix_prompt += "Stay within the sprint scope (docs, templates, root maintainers moves, gemspec metadata).\n";
    let fix = agent(fix_prompt, #{
        label: "fix-blockers",
        capability_mode: "all",
        agent_type: "coding-worker",
        output_schema: implement_schema,
    });
    if fix == () || !fix.success || fix.output == () || fix.output.ok != true {
        pause("verification", "Could not clear review blockers. Manual fix needed.");
    }
    let rev2 = agent(rev_prompt, #{
        label: "review-recheck",
        capability_mode: "read-only",
        agent_type: "reviewer",
        output_schema: review_schema,
    });
    if rev2 == () || !rev2.success || rev2.output == () || rev2.output.ok != true {
        pause("verification", "Blockers remain after fix pass.");
    }
    rev = rev2;
}

// --- Report -----------------------------------------------------------------
let report = "";
report += "# Professionalism sprint report\n\n";
report += "## Inventory\n";
report += inv.output.notes + "\n\n";
report += "## Implementation\n";
report += impl.output.summary + "\n\n";
report += "Changed paths: " + json_encode(impl.output.changed_paths) + "\n\n";
if impl.output.skipped != () {
    report += "Skipped: " + json_encode(impl.output.skipped) + "\n\n";
}
report += "## GitHub surface\n";
if gh != () && gh.success && gh.output != () {
    report += gh.output.summary + "\n";
    report += "Actions: " + json_encode(gh.output.actions) + "\n\n";
} else {
    report += "GitHub surface agent did not complete successfully.\n\n";
}
report += "## Verify\n";
report += ver.output.summary + "\n";
report += "Commands: " + json_encode(ver.output.commands) + "\n\n";
report += "## Review\n";
report += rev.output.summary + "\n";
report += "Blockers: " + json_encode(rev.output.blockers) + "\n";
report += "Concerns: " + json_encode(rev.output.concerns) + "\n";
report += "Nits: " + json_encode(rev.output.nits) + "\n\n";
report += "## Next (human)\n";
report += "- Review git diff and commit when satisfied (do not auto-commit from this workflow).\n";
report += "- Push when ready; run bin/check_ci_parity before push per repo rules.\n";

let path = write_scratch_file("professionalism-sprint-report.md", report);
log("Sprint complete — report at " + path);

complete(#{
    path: path,
    summary: "Professionalism sprint finished; review report and commit when ready",
    implement_ok: impl.output.ok,
    verify_ok: ver.output.ok,
    review_ok: rev.output.ok,
    github_ok: if gh != () && gh.success && gh.output != () { gh.output.ok } else { false },
});
