# Contributing

Thank you for your interest in contributing! Here's how to get started.

## Getting started

1. **Fork** the repository and clone your fork locally.
2. Create a **feature branch** from `main`:
   ```
   git checkout -b fix/describe-your-fix
   ```
   Branch naming conventions:
   - `fix/<short-description>` — bug fixes
   - `feat/<short-description>` — new features or enhancements
   - `docs/<short-description>` — documentation-only changes

## Making changes

- All scripts run inside **Sitecore PowerShell Extensions (SPE)**. Test your changes against a real Sitecore instance before submitting.
- Keep changes focused. One logical change per pull request.
- Update `CHANGELOG.md` under `[Unreleased]` to describe what you changed.
- Do **not** commit binary files (`.zip`, `.nupkg`). Release artifacts are distributed via GitHub Releases.

## Submitting a pull request

1. Push your branch to your fork.
2. Open a pull request against `main` on this repository.
3. Fill in the PR template completely.
4. A maintainer will review your PR. Please respond to any requested changes promptly.

## Code style

- Use `PascalCase` for function names and `camelCase` / `$PascalCase` for variables, consistent with existing scripts.
- Write clear inline comments for non-obvious logic.
- Prefer `-ErrorAction SilentlyContinue` with an explicit null-check over silently swallowing errors.

## Questions

Open a [Discussion](../../discussions) or an [Issue](../../issues) if you're unsure about anything before investing time in a large change.
