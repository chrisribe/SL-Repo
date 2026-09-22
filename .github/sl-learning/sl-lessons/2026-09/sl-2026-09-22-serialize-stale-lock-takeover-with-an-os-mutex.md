---
date: "2026-09-22"
id: "SL-20260922-SERIALIZE-STALE-LOCK-TAKEOVER-WITH-AN-OS-MUTEX"
kind: "pitfall"
lastVerifiedAt: "2026-09-22"
managedBy: "sl"
pinned: false
relatedTo: []
schemaVersion: 1
scope: "repository"
status: "raw"
trigger:
  - "stale lock ABA takeover"
---

## Context
The PowerShell mutation lock reclaimed an expired lock directory after
rechecking its timestamp and owner token, then renaming the lock path.

## What did NOT work
- Re-reading the timestamp and token immediately before `Directory.Move` did
  not make the move conditional on that observed directory. A contender could
  replace the lock after the recheck, causing takeover to move the new lock.

## Why
Path metadata comparison followed by rename is not compare-and-swap. Serialize
cooperating creation, stale validation, takeover, and release with the same
cross-process mutex. Keep inspection and takeover in one critical section,
including when extracting helper functions. Release the mutex before running
the repository operation; the directory lease protects that operation.

## Scope and limits
- All contenders must share the same named-mutex identity and OS namespace
  on one host. The PowerShell implementation derives that identity from the
  full lock path, uppercased on Windows; do not assume path aliases coordinate.
- The TypeScript lock does not acquire this mutex. This fix does not establish
  safe mixed TypeScript/PowerShell takeover or coordination across machines.
- These checks were run locally on Windows. They do not establish the result
  of the macOS/Linux CI matrix for this revision.

## Verified evidence
- [Implementation](../../../../SL-runtime-source/SL.Runtime.Core.ps1):
  `Invoke-SLWithMutationLock` uses `Invoke-SLWithMutationMutex` around
  acquisition/takeover and release.
- [Regression test](../../../../SL-tests/SL-integration/SL-powershell-runtime-lifecycle.test.ts):
  `prevents a replacement lock between stale revalidation and takeover` pauses
  the first process after its final ownership check and before the rename.
  A second process must complete with `mutation-lock-timeout`, without changing
  the stale owner. A later process must acquire after the first releases.
- Waiting for that explicit timeout replaces a 250 ms startup assumption.
  Temporarily bypassing the acquisition mutex made the test fail because the
  second process acquired during the pause. Restoring the mutex made it pass.
- The focused lock tests and `npm run ci` passed on Windows. The temporary
  bypass was removed; no deliberately unprotected code remains.

## Re-use cue
- Retrieve when implementing stale lock recovery, lease takeover, or any
  check-then-rename ownership transition. For concurrency regressions, force
  the disputed interleaving and verify that removing the guard fails the test.
