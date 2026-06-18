# Example Copilot Custom Agent Package

This folder contains an example GitHub Copilot customization package for MVC-to-Next.js component conversion workflows.

Important:

- This package is example-only and is not active by default.
- These files are templates and require path updates for your target project.

## Included Files

- `agents/mvc-to-nextjs.agent.md`: Example agent definition and workflow.
- `instructions/mvc-to-nextjs.instructions.md`: Example implementation rules.
- `prompts/convert-mvc-component.prompt.md`: Example reusable conversion prompt.

## How to Activate (Optional)

If you want to use this package in another repo:

1. Copy or adapt files into `.github/agents`, `.github/instructions`, and `.github/prompts` in that target repository.
2. Replace all `{{...}}` path variables with project-specific values.
3. Verify `applyTo` patterns, tool permissions, and file paths before running.
4. Test on a sample component first, then expand usage.

## Sanitization Checklist

Before sharing or reusing these files:

1. Remove private tenant names, internal URLs, and proprietary paths.
2. Remove hardcoded environment details that are not portable.
3. Confirm no secrets, credentials, or internal identifiers are included.

## Notes

This package is intended as an accelerator for teams who want to build and tune their own agent workflow. Keep behavior opt-in and repository-specific.