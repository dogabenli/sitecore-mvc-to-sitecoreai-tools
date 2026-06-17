# AI Guidelines for Contributors

This document provides guidance on effectively using AI (e.g., GitHub Copilot, Claude) while maintaining code quality and PowerShell best practices.

## When to Use AI

✅ **Good use cases:**
- Boilerplate code (function templates, parameter blocks)
- Error handling patterns (try-catch structures, logging)
- Iterating over collections (foreach loops, hashtable operations)
- Documentation and comments
- Test scenarios and edge cases

❌ **Avoid:**
- Complex Sitecore-specific logic (Sitecore PowerShell Extensions API calls)
- Security-sensitive code (credential handling, authorization logic)
- Breaking changes to existing scripts
- Code you don't fully understand before merging

## PowerShell Best Practices

All code—AI-generated or not—must follow these standards:

### Function Structure
- Use `[CmdletBinding()]` attribute on all functions
- Include parameter validation: `[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`
- Provide `[Parameter(...)]` blocks with descriptions
- Include a `<#...#>` comment block describing purpose, parameters, and examples

**Example:**
```powershell
function Migrate-Content {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Source item ID")]
        [Sitecore.Data.ID]$SourceId,
        
        [Parameter(HelpMessage = "Include child items")]
        [switch]$Recurse
    )
    
    # Function body...
}
```

### Error Handling
- **Never suppress errors silently.** Use `-ErrorAction SilentlyContinue` only with explicit null-checks.
- Always provide feedback when an operation fails.
- Use `-ErrorVariable` to capture errors for logging.

**Good:**
```powershell
$item = Get-Item -Path "master:" -ID $id -ErrorAction SilentlyContinue -ErrorVariable err
if ($err) {
    Write-Warning "Failed to retrieve item $id"
}
```

**Bad:**
```powershell
$item = Get-Item -Path "master:" -ID $id -ErrorAction SilentlyContinue
# No error handling—user has no idea if it failed
```

### Variable Naming
- Use descriptive, camelCase names: `$renderingMap`, `$datasourceId`, `$migrationPhase`
- Avoid abbreviations: `$rm` → `$renderingMap`, `$ds` → `$datasourceId`
- Prefix private/internal variables with underscore: `$_tempCache`

### Configuration & Magic Numbers
- **Never hardcode IDs or paths.** Use:
  - Configuration items in Sitecore
  - Parameters passed to functions
  - Centralized constants at the top of the script
- Example: instead of `$id = "{04646A89-996F-4EE7-878A-FFDBF1F0EF0D}"` inline, define once and reference

### Comments
- Explain the *why*, not the *what*
- One-line comments for single statements
- Block comments for complex logic flows

**Good:**
```powershell
# Fetch mappings from configuration item to avoid hardcoded IDs
$mappings = Get-RenderingMappings
```

**Bad:**
```powershell
# Get the mappings
$mappings = Get-RenderingMappings
```

### Testing
- Use `-WhatIf` simulation before destructive operations
- Test scripts in a non-production Sitecore environment first
- Include a rollback/revert function (see migration scripts for examples)

---

## Code Review Checklist for AI-Generated Code

When reviewing PRs with AI-assisted code, verify:

- [ ] Function has `[CmdletBinding()]` and `[Parameter(...)]` attributes
- [ ] Parameters are validated (e.g., `[ValidateNotNullOrEmpty()]`)
- [ ] Error handling is explicit; `-ErrorAction SilentlyContinue` only used intentionally
- [ ] Variable names are clear and follow camelCase naming
- [ ] No hardcoded IDs, paths, or credentials
- [ ] Logic tested against a real Sitecore instance (not just syntax)
- [ ] No external dependencies introduced without discussion
- [ ] Comments explain *why*, not just *what*
- [ ] Code aligns with existing script style in the repository

---

## Questions?

If you're unsure whether to use AI for a task, ask in a PR comment or open a Discussion. Better safe than sorry.
