# Sitecore MVC → SitecoreAI Migration Tools

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A collection of **Sitecore PowerShell Extensions (SPE)** scripts that automate the migration of a Sitecore MVC site to Headless SXA (JSS / Next.js).

---

## Disclaimer

This project is **not an official Sitecore tool** and is **not supported by Sitecore**.

Use of these scripts is at your own risk. Anyone using this tool is responsible for validating behavior in their own environments and for any impact caused by running the scripts.

This repository is open for contributions, and all scripts are publicly available.

---

## Purpose and Scope

The migration currently runs on local environments and is executed using two Sitecore PowerShell Extension scripts.

The primary objective of this approach is to help customers transition to SitecoreAI with the lowest possible effort. To support this, the scripts focus on an *as-is* (like-for-like) migration model, minimizing redesign and redevelopment rather than requiring a full rebuild.

This approach is **not intended to overlap with or replace Pathway**. It is specifically designed for scenarios where customers prefer a straightforward, low-effort migration of existing solutions while preserving current structures and behaviors as much as possible.

Anyone planning to use this tool should follow the step-by-step guide in [docs/step-by-step-migration.md](docs/step-by-step-migration.md).

---

## Contents

| Script | Purpose |
|--------|---------|
| [`scripts/Convert-mvc-to-headless-sxa.ps1`](scripts/Convert-mvc-to-headless-sxa.ps1) | Ten-phase migration: converts renderings, datasources, placeholders, page templates, standard values, and layout XML, with per-phase revert support |
| [`scripts/Migrate-items.ps1`](scripts/Migrate-items.ps1) | Remaps rendering IDs, datasource templates, placeholder keys, page templates, and layout references on live content items using stored mapping data |
| [`scripts/Get-SitePageCount.ps1`](scripts/Get-SitePageCount.ps1) | Counts MVC pages by template under a configured start path; useful for sizing a migration |

The installable Sitecore package (`.zip`) is available on the [Releases](../../releases) page.

---

## Prerequisites

- **Sitecore 10.4** 
    - If you plan to migrate from an older Sitecore version;
        - Setup a vanilla Sitecore instance
        - Run database upgrade scripts against your existing master database
        - Attach your master database to vanilla Sitecore instance
- Latest "Sitecore Headless Services" package (currently **Sitecore Headless Services Server XP 22.0.11** for XP) package installed
- Latest Sitecore PowerShell Extensions (SPE) (Currently **Sitecore.PowerShell.Extensions-7.0-IAR**) package installed
- Latest Sitecore Experience Accelerator (currently **Sitecore Experience Accelerator 10.4.0 rev. 08675**) package installed
- Latest MVC to Headless SXA Migration (currently **MVC to Headless SXA Migration-0.1.1-0.1.1**) package installed
- The **Migration Configuration** item provisioned at `/sitecore/system/Settings/Migration/Migration Configuration` (included in the package)
- Layout mappings are created manually under `/sitecore/system/Settings/Migration/Mappings/Layout Mappings`
- A target **Headless SXA** site structure already scaffolded

---


### 1. Install packages in prerequisites

Download `MVC to Headless SXA Migration-0.1.1.zip` from [Releases](../../releases) and install it through the Sitecore Installation Wizard. This provisions the Migration Configuration item and all required templates.

### 2. Configure the Migration Configuration item

Open `/sitecore/system/Settings/Migration/Migration Configuration` in the Content Editor and fill in.


### 3. Run `Convert-mvc-to-headless-sxa.ps1`

Open the script in SPE ISE and execute it. It runs ten sequential phases, pausing for confirmation between each phase. 

### 4. Run `Migrate-items.ps1`

After the conversion phase, run this script to remap content items. Select a source and target root item when prompted, and optionally include all descendants.

### 5. Run `Get-SitePageCount.ps1` (optional)

Use this diagnostic utility before or after migration to count pages per template and verify the scope of the migration.

---

## Documentation

For a detailed step-by-step migration guide with diagrams and video walkthrough, see [Migration Overview](docs/step-by-step-migration.md).

If you are using this tool, follow [docs/step-by-step-migration.md](docs/step-by-step-migration.md) as the primary runbook.

This includes:
- Phase-by-phase breakdown of the migration process
- Sitecore configuration examples
- Visual diagrams of MVC vs. Headless architectures
- Video demo of the migration workflow

Optional: an example Copilot custom agent package for Phase 7 is available at [examples/copilot-custom-agent](examples/copilot-custom-agent/README.md).

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](.github/CONTRIBUTING.md) before opening a pull request.

For guidance on using AI tools effectively while maintaining code quality, see [AI Guidelines](.github/AI-GUIDELINES.md).

---

## Security

To report a vulnerability, see [SECURITY.md](.github/SECURITY.md).

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
