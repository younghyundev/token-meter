---
name: release
description: Run the Token Meter release workflow: choose or bump a version, build the app, create the GitHub release asset, and update the Homebrew tap. Use when the user asks to cut a release or says `$release`.
---

<codex_skill_adapter>
## Invocation
- This skill is invoked by mentioning `$release`.
- Treat all text after `$release` as the target version string.
- If no version is provided, read the current version from `Resources/Info.plist` and bump the patch version.
</codex_skill_adapter>

# Release

Use this skill only for the Token Meter release pipeline in this repository.

## Workflow

1. Read [references/release-workflow.md](references/release-workflow.md).
2. Determine the target version.
3. Confirm the final version with the user before any mutating release step.
4. Execute the release steps sequentially and stop immediately on failure.

## Guardrails

- Run the workflow from the repository root: `/Users/gim-yeonghyeon/Desktop/token-meter`.
- Do not skip build verification.
- Do not push, tag, create a GitHub release, or update the Homebrew tap before user confirmation.
- When writing the release notes, summarize only user-facing changes since the previous tag.
