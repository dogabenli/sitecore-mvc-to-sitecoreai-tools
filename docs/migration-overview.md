MVC to SitecoreAI Migration via SPE scripts and XM to XM Cloud Tool Guide

This document outlines the steps to migrate a legacy MVC site to SitecoreAI using Sitecore PowerShell Scripts and the XM to XM Cloud Tool.

Migration Overview

![Migration Overview Diagram](images/1-16e08dba-2cc4-413f-bd6c-4c5caa67a030.png)

The migration phases are detailed below:

Phase 1

Install the necessary Sitecore packages.

![Install Packages](images/2-f9fc521a-59da-44dc-85b8-6be037762ce7.png)

After installing the MVC to Headless SXA Migration package, migration ribbons appear under the Developer tab.

![Developer Ribbon](images/3-8c0f58cf-2661-4811-bcf6-bc661f8d1001.png)

Phase 2

Create an empty Headless SXA site next to the legacy site.

![Create Headless SXA Site](images/4-d94e9e7a-875d-4c5c-85ec-867538e74e68.png)

For example:

![Example Site Structure](images/5-adb4840f-826b-4bb1-b6b1-9edf266aa77a.png)

Phase 3

Fill Migration Configuration item fields: `/sitecore/system/Settings/Migration/Migration Configuration`

![Migration Configuration](images/6-834d3dcd-ac8b-4ecb-9803-4593c7932a15.png)

Layout mappings are not automated; create layout migration maps manually under `/sitecore/system/Settings/Migration/Mappings/Layout Mappings`.

![Layout Migration Maps](images/7-283f90df-d99c-4f00-bf25-a1befb10aebc.png)

Phase 4

Run "Convert Items from MVC to Headless SXA" script. It automatically creates headless renderings, placeholders and migrate data sources.

![Convert Items Wizard](images/8-a043b2d5-3f48-4ce5-a859-38ca51722fe6.png)

Phase 5

Using “Migrate Pages”, legacy pages can be migrated to Headless SXA site.

![Migrate Pages Dialog](images/9-c245d933-7bf8-45b6-8ddc-265f079fe89b.png)

Migration updates all components and related data source references.

| MVC | Headless |
|-----|----------|
| ![MVC Layout and Renderings](images/10-3229bf49-9335-463d-a18d-2b28ce55a086.png) | ![Headless Layout and Renderings](images/11-a0a95819-7d5d-414b-9faa-464d2775bd39.png) |

The scripts handle dynamic placeholders automatically.

| MVC | Headless |
|-----|----------|
| ![MVC Placeholders](images/12-94834b24-b247-49eb-85aa-d8a15facea75.png) | ![Headless Placeholders](images/13-60d9be14-7117-4bea-9407-a8d7d2f6562f.png) |

After migration, page becomes available immediately in GraphQL layout service.

![GraphQL Layout Service Response](images/14-0f45ad6b-10e0-4000-9390-db05d9a99d2c.png)

Phase 6

After migration is completed and the GraphQL response is as expected, then the site can be migrated to SitecoreAI using the XM to XM Cloud Tool.

![Phase 6 Diagram](images/15-b59a3e65-8169-4671-93bc-ef41fa4d8ef2.png)

![XM Cloud Migration](images/16-4a55f94b-aa44-4d81-bfc4-c7547e576473.png)

Phase 7

You can build components using AI agents. The GraphQL layout service supplies page data. You have MVC references. Migration scripts generate a JSON reference listing all components, their data source fields, and rendering parameters.

![Build Components with AI Agents](images/17-0cf51e5f-8362-49ee-9a34-b8a2460fe7a7.png)

## Video Demo

<video width="100%" controls>
  <source src="videos/Recording 2026-06-03 095213.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>
