# Sitecore MVC → Headless SXA Migration Tools

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A collection of **Sitecore PowerShell Extensions (SPE)** scripts that automate the migration of a Sitecore MVC site to Headless SXA (JSS / Next.js).

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

- **Sitecore 10.x** (tested; may work on 9.x)
- **Sitecore PowerShell Extensions (SPE) 6.4+** installed and enabled
- The **Migration Configuration** item provisioned at `/sitecore/system/Settings/Migration/Migration Configuration` (included in the package)
- A target **Headless SXA** site structure already scaffolded

---

## Usage

All scripts are executed from the **SPE ISE** or **SPE Remoting** console inside your Sitecore instance.

### 1. Install the package

Download `MVC to Headless SXA Migration-0.1.1.zip` from [Releases](../../releases) and install it through the Sitecore Installation Wizard. This provisions the Migration Configuration item and all required templates.

### 2. Configure the Migration Configuration item

Open `/sitecore/system/Settings/Migration/Migration Configuration` in the Content Editor and fill in:

- **MVC Start Item** — root of the MVC content tree
- **MVC Page Type Templates** — pipe-separated template IDs/paths for MVC page templates
- **Local Data Source Template** — template ID used for local datasource folders

### 3. Run `Convert-mvc-to-headless-sxa.ps1`

Open the script in SPE ISE and execute it. It runs ten sequential phases, pausing for confirmation between each phase. Each phase can be reverted individually.

### 4. Run `Migrate-items.ps1`

After the conversion phase, run this script to remap content items. Select a source and target root item when prompted, and optionally include all descendants.

### 5. Run `Get-SitePageCount.ps1` (optional)

Use this diagnostic utility before or after migration to count pages per template and verify the scope of the migration.

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](.github/CONTRIBUTING.md) before opening a pull request.

---

## Security

To report a vulnerability, see [SECURITY.md](.github/SECURITY.md).

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
