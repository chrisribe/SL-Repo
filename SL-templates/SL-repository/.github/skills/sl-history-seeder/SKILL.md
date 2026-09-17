---
name: sl-history-seeder
description: "Seed SL with durable repository lessons from Git history. Use when asked to backfill memory, inspect historical fixes for gotchas, or initialize repository knowledge."
---

# SL history seeder

Extract evidence-backed lessons from Git history into SL. Use SL as the only
knowledge store; never create a parallel `.github/memory/` tree.

Set `$sl = '.github/sl-learning/sl-runtime/sl.ps1'` and invoke it with
`pwsh -NoProfile -File $sl`.

## Scope

- Pin the current revision and distinguish dirty changes.
- Use `.github/skills/sl-history-seeder/scripts/Get-HistorySeedEvidence.ps1`
   to inventory history and request batches of up to three commits. Commit mode
   saves each complete patch outside the repository and returns its `patchPath`.
   Read patches in focused ranges; use `-Path` for literal repository-relative
   files in large commits. Remove `evidenceDirectory` after review.
- Store resumable progress at the Git-private path returned by
   `git rev-parse --git-path sl-history-seeder-checkpoint.json`. After selecting
   the eligible queue and after every batch, write the pinned revision, scope,
   eligible/reviewed/deferred/remaining commit IDs, and lesson paths. Resume a
   matching checkpoint before inventory; replace a stale checkpoint only after
   reporting its revision mismatch. Delete it only after remaining is zero and
   final `project` and `validate` pass. Never put the checkpoint in the worktree.
- Default to all substantive first-parent commits from the last two months, in
  batches of up to three. If fewer than 20 remain after filtering, extend to 20,
  repository start, or one year. Do not widen an explicit range without approval.
- Exclude routine dependency, generated, handoff, and documentation-only changes
  unless requested. A quick sample stops after one batch only when explicit.
- Do not run target builds, tests, restores, installs, or deployments unless
  explicitly authorized. Inspect diffs, current code, and test assertions.

## Extract

For each batch, inspect focused diffs and one necessary ownership hop. Verify the
constraint against current code and intervening edits. Keep only non-obvious,
reusable rules that prevent a specific wrong action; defer unsupported claims.

Search applicable `sl-index.json` files and lesson bodies plus repository
instructions, skills, and agents before capture. Mark a finding covered when
equivalent applicable guidance is already retrievable from any of those sources;
cite its owner instead of duplicating it in SL. Code comments and ordinary docs
are evidence, not automatic reasons to skip a lesson. Generated lessons are
outputs, not evidence for later findings in the same run.

## Capture

For each missing lesson:

1. Run `capture` with a searchable title, kind, scope/target path, and exact
   retrieval triggers. Use `--dry-run` first.
2. Replace only the generated body; preserve all SL-managed frontmatter. Use:

   ```markdown
   ## Context
   <Trigger, current constraint, and short commit/code evidence.>

   ## What worked
   <Durable action and consequence.>

   ## Why
   <Underlying reason; include only safety-critical exceptions.>

   ## Re-use cue
   - <When a future agent should retrieve this lesson.>
   ```

   For pitfalls or mixed lessons, preserve and populate `What did NOT work`.
   Never leave placeholder text.
3. Check every compressed claim against current evidence. Preserve intentional
   exceptions and old/new ownership; verify paths and symbols. Narrow or defer
   instead of filling gaps with plausible terminology.
4. Run `project` and `validate` after each written batch. Normal Git/PR review is
   the approval gate. Do not create usage or promotion events for extraction.

Do not stage, commit, push, open a PR, promote, or forget unless explicitly
requested. Never persist source content, raw logs, prompts, secrets, personal data,
customer data, or absolute user paths.

## Report and continue

Report eligible/reviewed/deferred/remaining commits and captured/refined/skipped
lessons. Continue until the agreed scope is exhausted. On interruption, retain
remaining commit IDs and lesson paths. Historical fixes, extraction validation,
and PR approval are not verified reuse.