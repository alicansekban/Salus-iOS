# Salus iOS — Codex notes

- **Language rule (project-wide):** everything written into the repository is **English** — code comments, commit messages, branch names, PR descriptions, and every `.md` file. The only exception is conversation with the user, which stays Turkish. User-facing product strings are a separate matter: they ship in the `.xcstrings` catalogs, Turkish (default and fallback) and English, and Turkish UI copy is quoted verbatim.
- **Read before you touch an area.** The rules live once, in `.claude/rules/`; Codex and OpenCode do not load them by path, so open them yourself:
  - read `.claude/rules/architecture.md` before editing `**/App/**`, `**/Packages/**` or `**/project.yml`;
  - read `.claude/rules/design-system.md` before editing `**/Packages/SalusUI/**`, `**/Packages/SalusDesignSystem/**`, `**/Packages/Features/**` or `**/App/**`;
  - read `.claude/rules/copy.md` before editing `**/*.xcstrings`, `**/*Strings.swift`, `**/Packages/Features/**` or `**/App/**`;
  - read `.claude/rules/build.md` before editing `**/project.yml`, `**/Salus.xcodeproj/**`, `**/Package.swift`, `**/scripts/**`, `**/.swiftlint.yml` or `**/.swiftformat`;
  - read `.claude/rules/planning.md` before editing `**/docs/**`.
- **Global rules for every harness** — the read-first order (`docs/superpowers/STATUS.md`, the port contract in `../salus-android/docs/`, `docs/ios-feature-template.md`), comments explain why, the gates (`scripts/dev/gates.sh`, `scripts/ci.sh`), handover, the checkout policy, linear history and "commit and push only on the owner's word" — are in `CLAUDE.md`.
- Planning, status, handover and manual-QA rules: `.claude/rules/planning.md`. Manual QA on a simulator or device is the owner's job; do not drive one.

## Orchestration contract

- Follow implementer → task review (spec compliance + quality) → fixes and scoped re-review, at most five fix rounds. Resume the original implementer for early fixes. Record escalation or unresolved findings; do not silently change the owner's model policy.
- The coordinator owns dispatch; implementers and reviewers must not spawn their own helpers or reviewers. Do not run competing implementers against the same checkout (parallel tasks use separate `../wt-<x>` worktrees). Run `swift test` and `xcodebuild` serially: never two such jobs at once in one checkout.
- Record each coordinator decision as `Ruling: <decision> — <reason> — <cost if wrong>`. Keep deferred minors separate from required fixes. Final review findings go through one consolidated fix wave and a scoped re-review; report remaining rulings explicitly.
- Claude's `salus-implementer`, `salus-reviewer` and `salus-architect` are harness-specific agent types, not Codex types; in Codex pass the model explicitly and give each role a fresh task context with a brief, the relevant interfaces and decisions, and the report path.
