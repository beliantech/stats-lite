# Plan: purge .pi from git history and keep it ignored

## Trigger

- User command: ".pi should be gitignored and we need to clean up the git history."
- Risk class R2: the work rewrites every commit SHA and force-pushes `origin/main`.
- Oracle: mandatory for high blast radius. Two attempts ran (session
  `2026-10-16T09-22-58-274Z_da374b78`), both timed out with no result. Fallback: procedure
  facts verified by Google search (git-filter-repo docs and FAQ). No numeric estimate in
  this plan is used as a finding; all numbers below are measured.

## Current state vs target state

| Fact | Measured now | Target |
|---|---|---|
| `.pi/` in `.gitignore` | yes (line 2, since commit `88cc200`) | unchanged |
| Tracked files under `.pi/` | 195 | 0 |
| Tracked files that match ignore rules | 195 (all `.pi/*`) | 0 |
| Commits that touch `.pi/` | 16 of 45 | 0 |
| `.pi` objects reachable from any ref | 242 blobs (largest 43,810 B) | 0 |
| `artifacts/`, `worktrees/` ignored | no (untracked, no ignore rule) | ignored |
| `main` vs `origin/main` | main = origin/main + 1 (`108494f`) | identical after rewrite |
| `.git` size | 1.3 MB | smaller; exact value measured after purge |

Root cause (measured, not hypothesized): `.pi/` files were committed before the
`.gitignore` rule existed (`git log --diff-filter=A -- .pi` shows first adds in `bd29676`,
`664e280`, `f865de3`, `cd7df3f`, `06ebfea`; the ignore rule landed later in `88cc200`).
A `.gitignore` rule never untracks an already-tracked file, so 195 files stayed in the index.

Known facts that shape the procedure:

- `feat/2026-10-15-stats-lite-view-weight` is local-only, fully merged
  (`git rev-list --left-right --count main...feat/...` = `13 0`), absent from the remote.
- No tags, no stash, one registered worktree (main only).
- `worktrees/2026-10-15-stats-lite-view-weight/` on disk is a broken orphan: its `.git`
  file points at `/Users/jonathan/beliantech/stats-lite/.git/worktrees/...` (different repo
  name) and it reports "not a git repository". Existence of that path is unverified:
  `test -d /Users/jonathan/beliantech/stats-lite` times out in this environment.
- `git-filter-repo` is not installed. `brew` is available. git is 2.54.0.
- Verified by search: `git filter-repo` refuses non-fresh clones (bypass with `--force`),
  strips all remotes, and prunes reflogs. `--invert-paths --path .pi` purges the path from
  all history.

## In scope

1. Untrack the 195 `.pi/` files (keep them on disk).
2. Add `artifacts/` and `worktrees/` to `.gitignore`.
3. Rewrite all refs so no commit and no object contains a `.pi/` path.
4. Force-push the rewritten `main` to `git@github.com:beliantech/stats-lite-macos.git`.
5. Resync the local clone and drop old objects locally.
6. Prove a rollback path exists before the rewrite runs.

## Out of scope

- No source-code change of any kind.
- No deletion of on-disk `.pi/` content, `artifacts/`, or the orphaned `worktrees/` dir.
  Deleting local files is the user's decision; we only stop git from tracking them.
- No republish of the merged `feat/...` branch; it stays local-only and is deleted after
  its merge into main is re-verified.
- No claim that GitHub purges unreachable objects. GitHub may keep unreachable blobs for a
  grace period (unverified prior; exact retention is not documented in the sources found).
  If the concern is real data removal, open a GitHub support request after the rewrite.

## Experiment (one variable)

- Variable: the rewrite itself, run on a throwaway mirror clone in `/tmp` before anything
  touches GitHub.
- Measure: `git rev-list --objects --all | rg '\.pi/'` on the mirror, plus
  `git log --all --oneline -- .pi`.
- Falsification: if the scan still lists any `.pi` object, the rewrite failed. The force
  push does not run until the scan returns empty. If the scan returns empty, the rewrite is
  accepted and the push proceeds.
- One variable per round. Do not batch a `gc`, a branch delete, and a rewrite tweak into
  one measurement round.

## Three fixes if the measurement fails

1. Ref coverage: re-check `git for-each-ref` in the mirror and re-run
   `git filter-repo --invert-paths --path .pi --force` so every ref is filtered, then
   repeat the scan.
2. Reachable-object leftovers: run `git reflog expire --expire=now --all` and
   `git gc --prune=now` in the mirror, then repeat the scan.
3. Tool fallback: if `git-filter-repo` cannot install, run
   `git filter-branch --index-filter 'git rm -r --cached --ignore-unmatch .pi'
   --prune-empty --tag-name-filter cat -- --all` on the mirror, then repeat the scan.
   Cost note: `filter-branch` is slow and deprecated; on a 45-commit repo the runtime is
   negligible (unverified prior; measure it).

## Stop rule / failed case

Failed case: after two purge rounds the mirror scan still lists a `.pi` object.
Stop rule: halt, do not push, restore nothing locally (nothing was changed), and report
the scan output to the user. Do not improvise a fourth variant.

## VAC

N/A. This plan changes no user-visible surface. It touches git metadata only.

## Rollout (exact commands, in order)

Phase 0 — hygiene commit (local, no remote effect):

```sh
cd /Users/jonathan/beliantech/stats-lite-macos
git rm -r --cached .pi            # untracks; files stay on disk
# edit .gitignore: add "artifacts/" and "worktrees/"
git add .gitignore
git commit -m "chore(repo): untrack .pi plans and ignore artifacts/worktrees"
git ls-files -i -c --exclude-standard   # expect empty output
```

Phase 1 — backup and rollback proof:

```sh
git bundle create /Users/jonathan/beliantech/stats-lite-prepurge-2026-10-16.bundle --all
git bundle verify /Users/jonathan/beliantech/stats-lite-prepurge-2026-10-16.bundle
git clone --branch main /Users/jonathan/beliantech/stats-lite-prepurge-2026-10-16.bundle /tmp/bundle-check
git -C /tmp/bundle-check rev-parse HEAD   # must equal: git rev-parse main
```

The bundle lives outside the repo, is never pushed, and contains the `.pi` content on
purpose: it is the rollback artifact. Delete it only after the user confirms the rewrite.

Phase 2 — tool:

```sh
brew install git-filter-repo
git filter-repo --version
```

Phase 3 — rewrite on a mirror clone, then measure:

```sh
rm -rf /tmp/stats-lite-rewrite.git
git clone --mirror /Users/jonathan/beliantech/stats-lite-macos /tmp/stats-lite-rewrite.git
git -C /tmp/stats-lite-rewrite.git for-each-ref        # expect: main, feat/...
cd /tmp/stats-lite-rewrite.git
git filter-repo --invert-paths --path .pi --prune-empty yes --force
git log --oneline --all -- .pi                         # expect: empty
git rev-list --objects --all | rg '\.pi/'              # expect: empty
git log --oneline | wc -l                              # record before/after counts
```

Commits whose only content was a `.pi` file become empty and are pruned. Commits with real
changes keep all non-`.pi` changes; only `.pi` paths drop.

Phase 4 — force push, only after an empty scan:

```sh
cd /tmp/stats-lite-rewrite.git
git push --force git@github.com:beliantech/stats-lite-macos.git '+refs/heads/main:refs/heads/main'
```

Only `main` is pushed. The merged `feat/...` branch is not republished.

Phase 5 — resync the local clone and drop old objects:

```sh
cd /Users/jonathan/beliantech/stats-lite-macos
git fetch origin '+refs/heads/main:refs/remotes/origin/main' --prune
git reset --hard origin/main       # untracked .pi/, artifacts/, worktrees/ untouched
git reflog expire --expire=now --all
git gc --prune=now
git ls-remote origin               # expect one ref: refs/heads/main
```

Phase 6 — delete the merged branch (evidence-gated):

```sh
git -C /Users/jonathan/beliantech/stats-lite-macos rev-list --left-right --count main...feat/2026-10-15-stats-lite-view-weight
# pre-rewrite measurement recorded as 13 0 (fully merged). Delete only if the recorded
# measurement still shows 0 commits ahead; otherwise stop and report.
git branch -D feat/2026-10-15-stats-lite-view-weight
```

## Acceptance criteria (all must hold)

- A1 `git rev-list --objects --all | rg '\.pi/'` prints nothing.
- A2 `git log --all --oneline -- .pi` prints nothing.
- A3 `git ls-files -i -c --exclude-standard` prints nothing;
  `git check-ignore -v .pi artifacts worktrees` matches all three.
- A4 `git status --short` prints nothing.
- A5 `git ls-remote origin` shows `refs/heads/main` equal to local `git rev-parse main`.
- A6 `git fsck --no-progress` reports no errors.
- A7 `git diff <pre-rewrite-main-sha> origin/main --stat` lists only `.pi/` deletions and
  the `.gitignore` change. This proves no source file changed. `xcodebuild` build check is
  optional; `xcodebuild -list` stalled past 90 s in this environment (unverified prior on
  cause), so the tree-diff is the integrity proof.
- A8 Bundle restore test in Phase 1 passed.

## Rollback

Restore GitHub from the bundle, never from the rewritten clone:

```sh
git clone --branch main /Users/jonathan/beliantech/stats-lite-prepurge-2026-10-16.bundle /tmp/rollback
git -C /tmp/rollback push --force git@github.com:beliantech/stats-lite-macos.git '+refs/heads/main:refs/heads/main'
cd /Users/jonathan/beliantech/stats-lite-macos && git fetch --prune && git reset --hard origin/main
```

## Evidence Tasks

- ET1 Hygiene commit. Deliverable: commit SHA, output of
  `git ls-files -i -c --exclude-standard` (empty), output of `git check-ignore -v .pi
  artifacts worktrees`.
- ET2 Backup + rollback proof. Deliverable: bundle path, `git bundle verify` output,
  `git rev-parse HEAD` of the bundle clone vs local `git rev-parse main` (must match).
- ET3 Tool install. Deliverable: `git filter-repo --version` output.
- ET4 Mirror rewrite and pre-push measurement. Deliverable: empty `.pi` scan output,
  empty `git log --all -- .pi` output, commit counts before/after, `for-each-ref` output.
- ET5 Force push, local resync, local gc. Deliverable: `git ls-remote origin` output,
  `git status --short` (empty), `git fsck --no-progress` (clean), new `main` SHA.
- ET6 Acceptance. Deliverable: A1–A8 outputs, `.git` size after purge, deletion receipt for
  the merged branch (or the stop-rule report).

## Done

Done = GitHub `main` rewritten with zero `.pi` objects, local clone resynced and pruned,
all acceptance criteria A1–A8 recorded, and the result reported to the user. This plan runs
as ops by the planner; there is no code deliverable and no coder spawn.
