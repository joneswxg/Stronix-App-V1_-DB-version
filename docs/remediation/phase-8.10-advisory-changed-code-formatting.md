# Phase 8.10: Advisory changed-code formatting

## Purpose

Pull requests receive low-churn Swift formatting feedback only for code they add or remediate. This avoids a repository-wide legacy formatting diff while making the style of new owned code consistent. Formatting is independent of simulator builds, tests, and the strict repository-integrity gate so a reviewer can diagnose each result separately.

## Tool and policy

The repository uses exactly one formatter: [SwiftFormat 0.58.5](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.58.5). The CI archive is downloaded from that release, verified against SHA-256 `e3d59ebbbab3567f9f460e2d24983ed44de351bd80b9eb5b3cb14d06317df05c`, and checked again with `swiftformat --version`.

[`.swiftformat`](../../.swiftformat) fixes Swift 5.0, LF line endings, four-space indentation, and a small explicit layout-rule set. It deliberately avoids semantic rewrites, naming policy, ordering, and broad wrapping changes.

CI invokes SwiftFormat with `--lint --lenient`. It never autoformats, writes contributors' files, or runs against the entire repository. Formatting deviations are reported as advisory diagnostics; unavailable/mismatched tools, invalid revisions, missing configuration, and other setup failures remain failures because they do not represent style feedback.

## Owned changed-code selection

`tools/lint_changed_swift_format.py` compares `BASE...HEAD` through Git using NUL-delimited paths and `--diff-filter=ACMR`. It sends only existing, tracked Swift paths under these repository-owned roots to SwiftFormat:

- `Stronix-App/Sources/`
- `Stronix-App/Tests/`

The allowlist excludes generated output, vendored dependencies, package checkouts, `Pods`, `Carthage`, `SourcePackages`, `.build`, and all other non-owned inputs by construction. Deleted paths are never linted. When no eligible Swift file changed, the runner exits successfully with an explicit message.

The independent **Swift changed-code formatting** workflow job checks out full history, installs the verified pinned archive, and chooses a base according to its event: the pull-request base SHA, the prior push SHA, or `origin/<base_ref>` for a manual dispatch. The runner’s three-dot comparison resolves the merge base in every case.

## Local command

Install SwiftFormat 0.58.5, verify `swiftformat --version` reports `0.58.5`, fetch `origin/main`, then run from the repository root:

```bash
python3 tools/lint_changed_swift_format.py \
  --base "$(git merge-base origin/main HEAD)"
```

The command is read-only and produces the same advisory diagnostics as CI. If you decide to make a reported file conform, run SwiftFormat outside CI only on the file(s) you intend to edit, review the diff, and rerun the lint command.

## Advisory rollout and promotion

Formatting remains advisory. A separate, explicitly reviewed change may consider making it blocking only after all of the following evidence is recorded:

- at least 20 consecutive pull-request runs spanning at least two weeks;
- stable archive installation, checksum verification, and version checks;
- no generated, vendored, or non-owned path selection;
- actionable findings without broad per-file suppressions or unresolved rule ambiguity; and
- normal changed-code work remediates findings without requiring a legacy-wide formatting sweep.
