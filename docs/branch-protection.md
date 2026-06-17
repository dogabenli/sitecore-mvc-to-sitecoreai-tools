# Setting up Branch Protection on GitHub

These settings enforce code review on every pull request and prevent anyone (including you) from pushing directly to `main`.

## Step-by-step

1. Go to your repository on GitHub.
2. Click **Settings** → **Branches** (under *Code and automation*).
3. Click **Add branch ruleset** (or **Add rule** on older UI).

### Recommended ruleset for `main`

| Setting | Value |
|---------|-------|
| **Branch name pattern** | `main` |
| **Restrict pushes** | Enabled (blocks force pushes and direct commits) |
| **Require a pull request before merging** | Enabled |
| — Require approvals | **1** |
| — Dismiss stale pull request approvals when new commits are pushed | Enabled |
| — Require review from Code Owners | **Enabled** ← this ties CODEOWNERS to the rule |
| **Require status checks to pass before merging** | Optional — enable if you add CI/CD later |
| **Block force pushes** | Enabled |
| **Restrict deletions** | Enabled |

4. Click **Save changes**.

## What this achieves

- Every PR to `main` requires your explicit approval (you are the CODEOWNER).
- Stale approvals are dismissed if the PR is updated after approval, so you always review the latest version.
- Nobody can bypass the rule by pushing directly or force-pushing.

## Applying the same rule to future release branches

Repeat the steps above with a pattern like `release/*` if you introduce versioned release branches.
