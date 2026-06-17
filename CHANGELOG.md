# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-06-17

### Added
- `Convert-mvc-to-headless-sxa.ps1` — ten-phase migration script that converts Sitecore MVC renderings, datasources, placeholders, page templates, standard values, and layout XML to Headless SXA equivalents, with per-phase revert support
- `Migrate-items.ps1` — content migration script that remaps rendering IDs, datasource templates, placeholder keys, page templates, and layout references on live content items using stored mapping data
- `Get-SitePageCount.ps1` — utility script that counts MVC pages by template under a configured start path, using the Migration Configuration item

[Unreleased]: https://github.com/dogabenli/sitecore-mvc-to-sitecoreai-tools/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/dogabenli/sitecore-mvc-to-sitecoreai-tools/releases/tag/v0.1.1
