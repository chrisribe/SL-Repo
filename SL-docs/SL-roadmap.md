# SL roadmap

## SL Repo

Repository-local capture, reuse, promotion, validation, installation, and
forgetting.

Implemented lifecycle capabilities include immutable usage and lifecycle
events, version-specific projections, governed
probation and activation, validation contracts, bounded executable checks,
deterministic projection repair, and retention integration.

Current limitations:

- Instruction usage requires an applying agent or host to emit a receipt.
- Outcome association is not proof of causal improvement.
- Obvious declaration conflicts are detected; semantic contradictions still
  require repository review.
- The optional GitHub Actions adapter requires `SL_REPO_TOKEN` when it reads
  the current private GitHub source. The Azure Pipelines adapter instead uses
  normal repository-resource authorization. Local operation requires neither
  adapter.

### Historical memory seeding (initial integration)

The bundled `sl-history-seeder` skill adapts the Repository Memory Compiler's
change-first extraction to SL. Standalone repositories can keep the compiler's
Markdown workflow; SL repositories use one knowledge store and the existing
capture, retrieval, and lifecycle.

Implemented handoff:

1. Use the bundled read-only evidence helper to inventory Git history. It keeps
  terminal JSON small, saves complete patches outside the repository, and can
  narrow large commits to literal repository-relative paths.
2. Inspect focused patch evidence and current code; extract scoped, durable lessons.
3. Compare with SL knowledge and other proposals from the run. Generated text is
   output for deduplication, not evidence for further findings.
4. Write supported proposals through SL capture for normal Git/PR review, with
   triggers, repository scope, and commit/code evidence. No per-entry approval
   prompts unless the user requests them.
5. Populate the returned lesson body, preserving generated metadata, then run
   `project` and `validate`. Do not create a parallel `.github/memory/` store or
   install a second live-capture instruction block.

Implementation boundary: [capture](../SL-src/SL-core/SL-capture.ts) currently
registers a skeleton, not a supplied lesson body. The skill replaces only that
body, preserves SL-managed frontmatter, and runs `project` and `validate`. Consider
a body-input API only if the end-to-end proof exposes a concrete need.

Keep these lifecycle boundaries:

- Raw lessons are already retrievable locally before merge; raw is not a pending
  approval state. Do not use this run's generated lessons to validate themselves.
- Historical fixes, extraction checks, and PR approval are not reuse votes.
  Record usage only when a later task actually applies the lesson.
- Content revisions must retain SL's version-specific evidence semantics.
  Promotion/activation and deletion must use existing governed operations.
- A prose retirement condition is review context, not authorization to delete.
  Rarely reused seeds may reach SL's 90-day stale threshold; decide retention
  deliberately rather than fabricating usage or pinning every seed.

The integration test proves capture, complete-body replacement, retrieval, and
validation with preserved metadata, no placeholders, and no synthetic usage. The
next operational proof is to apply a seeded lesson during a relevant later task
and record its observed outcome; do not force promotion.

This integration packages and validates the local workflow; it is not measured
productivity evidence. No scheduler, centralized service, or generalized import
framework is needed. See [lifecycle](SL-lifecycle.md) and [usage
receipts](SL-usage-events.md).

## SL Org

Future work:

- Submit cross-repository promotion candidates.
- Review and publish versioned team or organization packs.
- Enforce repository access boundaries.
- Distribute approved capabilities through a private marketplace.

## SL Company

Future work:

- Federated catalogs across organizations.
- Company policy precedence.
- Permission-aware retrieval.
- Data residency, compliance, and retention governance.

SL Org and SL Company are explicitly outside the current implementation.
